import DeflowCore
import ServiceManagement
import SwiftUI

struct MenuLabel: View {
    @ObservedObject var monitor: CalendarMonitor

    var body: some View {
        HStack(spacing: 4) {
            if monitor.isSignedIn {
                Image(nsImage: Brand.menuGlyph)
            } else {
                Image(systemName: "exclamationmark.circle")
            }
            if let next = monitor.upcoming.first(where: { $0.start > monitor.now }),
               next.start.timeIntervalSince(monitor.now) < 3600 {
                Text(Countdown.short(next.start.timeIntervalSince(monitor.now)))
            }
        }
    }
}

private enum Theme {
    static let ink = Color(red: 0.045, green: 0.03, blue: 0.07)
    static let amber = Color(red: 1.0, green: 0.74, blue: 0.42)
    static let ember = Color(red: 1.0, green: 0.45, blue: 0.12)
    static let magenta = Color(red: 0.70, green: 0.10, blue: 0.38)
    static let text = Color.white.opacity(0.92)
    static let dim = Color.white.opacity(0.58)
    static let faint = Color.white.opacity(0.34)
    static let hairline = Color.white.opacity(0.09)
    static let fill = Color.white.opacity(0.07)
}

struct MenuPanel: View {
    @ObservedObject var monitor: CalendarMonitor
    @AppStorage(Prefs.lead) private var lead = 60.0
    @AppStorage(Prefs.sound) private var sound = true
    @AppStorage(Prefs.callsOnly) private var callsOnly = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header.padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 14)

            Group {
                if !monitor.isSignedIn {
                    connectCard
                } else {
                    agenda
                }
            }
            .padding(.horizontal, 12)

            rule.padding(.top, 14)
            settings.padding(.horizontal, 18).padding(.vertical, 14)
            rule
            footer.padding(.horizontal, 12).padding(.vertical, 10)
        }
        .frame(width: 360)
        .foregroundStyle(Theme.text)
        .background {
            ZStack {
                Theme.ink
                RadialGradient(colors: [Theme.ember.opacity(0.30), .clear],
                               center: .topTrailing, startRadius: 0, endRadius: 300)
                RadialGradient(colors: [Theme.magenta.opacity(0.22), .clear],
                               center: UnitPoint(x: 0.1, y: 0.25), startRadius: 0, endRadius: 260)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var rule: some View { Rectangle().fill(Theme.hairline).frame(height: 1) }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            BrandMark().frame(width: 17, height: 17)
            Text("Deflow").font(.system(size: 19, weight: .semibold, design: .serif))
            Spacer()
            Circle().fill(statusColor).frame(width: 6, height: 6)
            Text(statusText)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.dim)
                .lineLimit(1)
        }
    }

    private var statusColor: Color {
        switch monitor.access {
        case .granted: Color(red: 0.45, green: 0.9, blue: 0.6)
        case .connecting: Theme.amber
        default: Color(red: 1.0, green: 0.45, blue: 0.4)
        }
    }

    private var statusText: String {
        switch monitor.access {
        case .granted: monitor.account ?? "Connected"
        case .connecting: "Signing in…"
        case .signedOut: "Not connected"
        case .failed: monitor.isSignedIn ? "Sync problem" : "Not connected"
        }
    }

    // MARK: - Agenda

    private var agenda: some View {
        let events = Array(monitor.upcoming.filter { $0.end > monitor.now }.prefix(6))
        return VStack(alignment: .leading, spacing: 10) {
            if case .failed(let why) = monitor.access { warning("Last sync failed: \(why)").padding(.horizontal, 6) }
            if let next = events.first {
                heroCard(next)
                if events.count > 1 {
                    VStack(spacing: 0) {
                        ForEach(Array(events.dropFirst().enumerated()), id: \.element.id) { i, e in
                            if let day = dayLabel(for: e, after: i == 0 ? next : events[i]) {
                                sectionTitle(day)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 6).padding(.top, 8).padding(.bottom, 2)
                            }
                            row(e)
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nothing for 24 hours.")
                        .font(.system(size: 22, weight: .medium, design: .serif))
                    Text("Stay in flow. Deflow will pull you out when it matters.")
                        .font(.system(size: 12)).foregroundStyle(Theme.dim)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(card)
            }
        }
    }

    private func heroCard(_ e: MeetingEvent) -> some View {
        let live = e.start <= monitor.now
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(live ? "HAPPENING NOW" : "UP NEXT IN")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(Theme.amber)
                Spacer()
                Text(timeRange(e))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.dim)
            }
            Text(live ? "Now" : Countdown.short(e.start.timeIntervalSince(monitor.now)))
                .font(.system(size: 44, weight: .medium, design: .serif))
                .monospacedDigit()
                .padding(.top, 2)
            Text(e.title)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(2)
                .padding(.top, 2)
            HStack(alignment: .center, spacing: 8) {
                if let who = e.attendeeSummary {
                    Text("with \(who)")
                        .font(.system(size: 12)).foregroundStyle(Theme.dim).lineLimit(1)
                }
                Spacer(minLength: 0)
                if let link = e.link {
                    Button { link.open() } label: {
                        Label("Join \(link.provider.rawValue)", systemImage: "video.fill")
                    }
                    .buttonStyle(Pill(prominent: true))
                }
            }
            .padding(.top, e.attendeeSummary == nil && e.link == nil ? 0 : 10)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(card)
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(LinearGradient(colors: [Color.white.opacity(0.11), Color.white.opacity(0.04)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
    }

    private func row(_ e: MeetingEvent) -> some View {
        HStack(spacing: 10) {
            Text(e.start.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.dim)
                .frame(width: 60, alignment: .leading)
            Text(e.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
            Spacer(minLength: 6)
            if e.link != nil {
                Image(systemName: "video.fill").font(.system(size: 9)).foregroundStyle(Theme.faint)
            }
            Text(Countdown.short(e.start.timeIntervalSince(monitor.now)))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.faint)
        }
        .padding(.horizontal, 6)
        .frame(height: 28)
    }

    private func timeRange(_ e: MeetingEvent) -> String {
        let t = Date.FormatStyle(date: .omitted, time: .shortened)
        return "\(e.start.formatted(t)) – \(e.end.formatted(t))"
    }

    /// "TOMORROW" etc. when an event falls on a different day than the one listed before it.
    private func dayLabel(for e: MeetingEvent, after previous: MeetingEvent) -> String? {
        let cal = Calendar.current
        guard !cal.isDate(e.start, inSameDayAs: previous.start) else { return nil }
        return cal.isDateInTomorrow(e.start) ? "TOMORROW"
            : e.start.formatted(.dateTime.weekday(.wide)).uppercased()
    }

    // MARK: - Settings

    private var settings: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                sectionTitle("TAKE OVER MY SCREEN")
                HStack(spacing: 3) {
                    leadOption("At start", 0)
                    leadOption("1 min", 60)
                    leadOption("2 min", 120)
                    leadOption("5 min early", 300)
                }
                .padding(3)
                .background(Theme.fill, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            VStack(spacing: 9) {
                Toggle("Chime until I respond", isOn: $sound)
                Toggle("Skip solo events with no call link", isOn: $callsOnly)
                    .onChange(of: callsOnly) { monitor.refresh() }
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in
                        do {
                            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }
            .toggleStyle(Switch())
            .font(.system(size: 13))
        }
    }

    private func leadOption(_ title: String, _ value: Double) -> some View {
        let on = lead == value
        return Button { lead = value } label: {
            Text(title)
                .font(.system(size: 12, weight: on ? .semibold : .regular))
                .foregroundStyle(on ? Theme.text : Theme.dim)
                .frame(maxWidth: .infinity)
                .frame(height: 24)
                .background(on ? Color.white.opacity(0.16) : .clear,
                            in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 6) {
            Button { AppState.shared.presentDemo() } label: {
                Label("Test takeover", systemImage: "play.fill")
            }
            .buttonStyle(Pill())
            Spacer()
            if monitor.isSignedIn {
                Button("Disconnect") { monitor.disconnect() }.buttonStyle(Quiet())
            }
            Button("Quit") { NSApp.terminate(nil) }.buttonStyle(Quiet())
        }
    }

    // MARK: - Connect cards

    private var connectCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Connect Google Calendar").font(.system(size: 20, weight: .medium, design: .serif))
            if case .failed(let why) = monitor.access { warning(why) }
            Text(monitor.access == .connecting
                 ? "Waiting for you to approve access in the sign-in window."
                 : "Deflow only asks to read your calendar. Nothing leaves this Mac.")
                .font(.system(size: 12)).foregroundStyle(Theme.dim)
            Button(monitor.access == .connecting ? "Waiting…" : "Sign in with Google") { monitor.connect() }
                .buttonStyle(Pill(prominent: true))
                .disabled(monitor.access == .connecting)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(card)
    }

    // MARK: - Bits

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .tracking(1.6)
            .foregroundStyle(Theme.faint)
    }

    private func warning(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.system(size: 11))
            .foregroundStyle(Theme.amber)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Control styles

private struct Pill: ButtonStyle {
    var prominent = false
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(.titleAndIcon)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(prominent ? Color.black : Theme.text)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(prominent ? Color.white : Color.white.opacity(0.10), in: Capsule())
            .opacity(!enabled ? 0.5 : configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
}

private struct Quiet: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(configuration.isPressed ? Theme.text : Theme.dim)
            .padding(.horizontal, 8)
            .frame(height: 28)
            .contentShape(Rectangle())
    }
}

private struct Switch: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack {
                configuration.label.foregroundStyle(Theme.text)
                Spacer()
                Capsule()
                    .fill(configuration.isOn ? Theme.amber : Color.white.opacity(0.14))
                    .frame(width: 32, height: 19)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle()
                            .fill(configuration.isOn ? Theme.ink : Color.white.opacity(0.85))
                            .padding(2.5)
                    }
                    .animation(.snappy(duration: 0.18), value: configuration.isOn)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
