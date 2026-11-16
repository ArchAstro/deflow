import Foundation

/// Decoding and filtering of Google Calendar API v3 responses. No networking here, so it is unit-testable.
public enum GoogleCalendar {
    public struct CalendarInfo: Equatable, Sendable {
        public let id: String
        public let name: String
        public let isPrimary: Bool
    }

    /// Calendars worth interrupting for: ones you own and have ticked in Google Calendar.
    /// Coworkers' calendars you merely subscribe to are left out.
    public static func decodeCalendars(_ data: Data) throws -> [CalendarInfo] {
        try JSONDecoder().decode(CalendarList.self, from: data).items.orEmpty
            .filter { $0.accessRole == "owner" && ($0.selected ?? false || $0.primary ?? false) && !($0.hidden ?? false) }
            .map { CalendarInfo(id: $0.id, name: $0.summaryOverride ?? $0.summary ?? $0.id, isPrimary: $0.primary ?? false) }
    }

    /// Timed events you have not declined. Drops cancelled, all-day, out-of-office and working-location entries.
    public static func decodeEvents(_ data: Data, calendarName: String) throws -> [MeetingEvent] {
        try JSONDecoder().decode(EventList.self, from: data).items.orEmpty.compactMap { e in
            guard e.status != "cancelled",
                  !["outOfOffice", "workingLocation", "birthday"].contains(e.eventType ?? "default"),
                  let start = e.start?.dateTime.flatMap(parseDate),
                  let end = e.end?.dateTime.flatMap(parseDate)
            else { return nil }

            let attendees = e.attendees.orEmpty
            if attendees.first(where: { $0.isSelf ?? false })?.responseStatus == "declined" { return nil }

            let video = e.conferenceData?.entryPoints?.first { $0.entryPointType == "video" }
            let code = (video?.passcode ?? video?.pin).map { "Passcode: \($0)" }
            var location = e.location?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let l = location, l.isEmpty || l.lowercased().contains("http") { location = nil }

            return MeetingEvent(
                id: "\(e.iCalUID ?? e.id)|\(start.timeIntervalSince1970)",
                title: (e.summary?.isEmpty == false ? e.summary : nil) ?? "Busy",
                start: start,
                end: end,
                calendarName: calendarName,
                location: location,
                attendees: attendees
                    .filter { !($0.isSelf ?? false) && !($0.resource ?? false) }
                    .compactMap { $0.displayName ?? $0.email },
                link: MeetingLink.find(in: [video?.uri, e.hangoutLink, code, e.location, e.description])
            )
        }
    }

    public static func parseDate(_ s: String) -> Date? {
        let plain = ISO8601DateFormatter()
        if let d = plain.date(from: s) { return d }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: s)
    }

    // MARK: - Wire types

    struct CalendarList: Decodable { let items: [Item]?
        struct Item: Decodable {
            let id: String
            let summary: String?
            let summaryOverride: String?
            let accessRole: String?
            let selected: Bool?
            let hidden: Bool?
            let primary: Bool?
        }
    }

    struct EventList: Decodable { let items: [Event]? }

    struct Event: Decodable {
        let id: String
        let iCalUID: String?
        let status: String?
        let eventType: String?
        let summary: String?
        let description: String?
        let location: String?
        let hangoutLink: String?
        let start: When?
        let end: When?
        let attendees: [Attendee]?
        let conferenceData: Conference?
    }

    struct When: Decodable { let dateTime: String? }

    struct Attendee: Decodable {
        let email: String?
        let displayName: String?
        let isSelf: Bool?
        let resource: Bool?
        let responseStatus: String?
        enum CodingKeys: String, CodingKey { case email, displayName, isSelf = "self", resource, responseStatus }
    }

    struct Conference: Decodable { let entryPoints: [EntryPoint]?
        struct EntryPoint: Decodable {
            let entryPointType: String?
            let uri: String?
            let passcode: String?
            let pin: String?
        }
    }
}

private extension Optional where Wrapped: Collection & ExpressibleByArrayLiteral {
    var orEmpty: Wrapped { self ?? [] }
}
