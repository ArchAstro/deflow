import AppKit
import DeflowCore
import os

private let log = Logger(subsystem: "dev.deflow.app", category: "sync")

enum Prefs {
    static let lead = "leadSeconds"
    static let sound = "soundEnabled"
    static let callsOnly = "callsOnly"

    static func register() {
        UserDefaults.standard.register(defaults: [lead: 60, sound: true, callsOnly: false])
    }
}

/// Polls Google Calendar and fires `onTrigger` when a meeting is due.
@MainActor
final class CalendarMonitor: ObservableObject {
    enum Access: Equatable {
        case signedOut
        case connecting
        case granted
        case failed(String)   // last sync failed; cached events still fire
    }

    @Published private(set) var access: Access = .signedOut
    @Published private(set) var account: String?
    @Published private(set) var upcoming: [MeetingEvent] = []
    @Published private(set) var now = Date()

    var onTrigger: (MeetingEvent) -> Void = { _ in }
    var canPresent: () -> Bool = { true }
    /// False until `start()`, so nothing reads the Keychain before the app is really running.
    var isSignedIn: Bool { isDemo || (started && auth.isSignedIn) }
    private var isDemo = false
    private var started = false

    private let auth = GoogleAuth()
    private var handled: Set<String> = []
    private var snoozedUntil: [String: Date] = [:]
    private var tickTimer: Timer?
    private var lastRefresh = Date.distantPast
    private var refreshTask: Task<Void, Never>?

    func start() {
        started = true
        access = auth.isSignedIn ? .granted : .signedOut
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.tick(); self?.refresh() }
        }
        tickTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        tickTimer?.tolerance = 0.3
        refresh()
    }

    // MARK: - Account

    func connect() {
        guard access != .connecting else { return }
        access = .connecting
        Task {
            do {
                try await auth.signIn()
                access = .granted
                refresh()
            } catch {
                access = .failed(error.localizedDescription)
            }
        }
    }

    func disconnect() {
        refreshTask?.cancel()
        refreshTask = nil
        auth.signOut()
        upcoming = []
        account = nil
        access = .signedOut
    }

    /// Sample agenda for design snapshots; never touches the network.
    func loadDemo() {
        isDemo = true
        access = .granted
        account = "you@example.com"
        let t = Date()
        func ev(_ title: String, _ mins: Double, _ len: Double, _ who: [String], call: Bool) -> MeetingEvent {
            MeetingEvent(id: title, title: title, start: t.addingTimeInterval(mins * 60),
                         end: t.addingTimeInterval((mins + len) * 60), calendarName: "Work", attendees: who,
                         link: call ? MeetingLink.find(in: ["https://acme.zoom.us/j/84512345678"]) : nil)
        }
        upcoming = [
            ev("Acme Robotics — pilot kickoff", 12, 30, ["Dana Whitfield", "Luis Ortega", "Priya Nair", "Sam Cho"], call: true),
            ev("Pricing review", 95, 45, ["Jo Lind"], call: true),
            ev("Dentist", 260, 60, [], call: false),
            ev("Daily check-in", 1150, 15, ["Team"], call: true),
            ev("Northwind renewal call", 1290, 30, ["Avery Stone"], call: true),
        ]
    }

    func snooze(_ event: MeetingEvent, for seconds: TimeInterval = 60) {
        snoozedUntil[event.id] = Date().addingTimeInterval(seconds)
        handled.remove(event.id)
    }

    // MARK: - Sync

    /// Pulls the next 24h (plus anything that started in the last 15 min) from every calendar you own.
    func refresh() {
        guard auth.isSignedIn, refreshTask == nil else { return }
        lastRefresh = Date()
        refreshTask = Task {
            defer { refreshTask = nil }
            do {
                let events = try await fetch()
                guard !Task.isCancelled else { return }
                let callsOnly = UserDefaults.standard.bool(forKey: Prefs.callsOnly)
                upcoming = events.filter { !callsOnly || $0.link != nil || !$0.attendees.isEmpty }
                access = .granted
                log.notice("sync ok: \(events.count, privacy: .public) events in window, \(self.upcoming.count, privacy: .public) kept")
            } catch GoogleAuth.Failure.signedOut {
                log.error("sync failed: signed out")
                upcoming = []
                access = .signedOut
            } catch is CancellationError {
            } catch {
                guard !Task.isCancelled else { return }
                access = .failed(error.localizedDescription)
                log.error("sync failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func fetch() async throws -> [MeetingEvent] {
        let base = "https://www.googleapis.com/calendar/v3"
        let calendars = try GoogleCalendar.decodeCalendars(
            try await get("\(base)/users/me/calendarList?minAccessRole=owner&maxResults=250"))
        account = calendars.first(where: \.isPrimary)?.id

        let iso = ISO8601DateFormatter()
        let from = Date().addingTimeInterval(-15 * 60)
        var seen: Set<String> = []
        var all: [MeetingEvent] = []
        for cal in calendars {
            let id = cal.id.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? cal.id
            var c = URLComponents(string: "\(base)/calendars/\(id)/events")!
            c.queryItems = [
                .init(name: "timeMin", value: iso.string(from: from)),
                .init(name: "timeMax", value: iso.string(from: from.addingTimeInterval(24 * 3600))),
                .init(name: "singleEvents", value: "true"),
                .init(name: "orderBy", value: "startTime"),
                .init(name: "maxResults", value: "100"),
            ]
            // URLComponents leaves "+" alone, which servers read as a space in timestamps.
            c.percentEncodedQuery = c.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
            let events = try GoogleCalendar.decodeEvents(try await get(c.string!), calendarName: cal.name)
            all += events.filter { seen.insert($0.id).inserted }
        }
        return all.sorted { $0.start < $1.start }
    }

    private func get(_ url: String, retry: Bool = true) async throws -> Data {
        var req = URLRequest(url: URL(string: url)!)
        req.timeoutInterval = 20
        req.setValue("Bearer \(try await auth.accessToken())", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401, retry {
            auth.invalidateAccessToken()
            return try await get(url, retry: false)
        }
        guard (200..<300).contains(status) else {
            struct APIError: Decodable { let error: Body; struct Body: Decodable { let message: String } }
            let message = (try? JSONDecoder().decode(APIError.self, from: data))?.error.message
            throw GoogleAuth.Failure.server(message ?? "Google Calendar returned HTTP \(status).")
        }
        return data
    }

    // MARK: - Triggering

    private func tick() {
        now = Date()
        if now.timeIntervalSince(lastRefresh) > 60 { refresh() }
        guard canPresent() else { return }

        let policy = TriggerPolicy(lead: UserDefaults.standard.double(forKey: Prefs.lead))
        for event in upcoming where !handled.contains(event.id) {
            let due: Bool
            if let until = snoozedUntil[event.id] {
                due = now >= until
            } else {
                due = policy.isDue(event, now: now)
            }
            guard due else { continue }
            handled.insert(event.id)
            snoozedUntil[event.id] = nil
            onTrigger(event)
            return
        }
    }
}
