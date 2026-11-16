import Foundation

/// Calendar event reduced to what the takeover needs. Plain data so it is testable without EventKit.
public struct MeetingEvent: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let start: Date
    public let end: Date
    public let calendarName: String
    public let location: String?
    public let attendees: [String]
    public let link: MeetingLink?

    public init(id: String, title: String, start: Date, end: Date, calendarName: String,
                location: String? = nil, attendees: [String] = [], link: MeetingLink? = nil) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.calendarName = calendarName
        self.location = location
        self.attendees = attendees
        self.link = link
    }

    /// "Dana, Luis, Priya +2"
    public var attendeeSummary: String? {
        guard !attendees.isEmpty else { return nil }
        let shown = attendees.prefix(3).joined(separator: ", ")
        let extra = attendees.count - 3
        return extra > 0 ? "\(shown) +\(extra)" : shown
    }
}

/// Decides when an event should take over the screen.
public struct TriggerPolicy: Sendable {
    /// Seconds before the start time to fire.
    public var lead: TimeInterval
    /// How long after the start an unseen event still fires (covers wake-from-sleep and late launches).
    public var grace: TimeInterval

    public init(lead: TimeInterval, grace: TimeInterval = 600) {
        self.lead = lead
        self.grace = grace
    }

    public func isDue(_ event: MeetingEvent, now: Date) -> Bool {
        let open = event.start.addingTimeInterval(-lead)
        let close = max(min(event.end, event.start.addingTimeInterval(grace)),
                        event.start.addingTimeInterval(60))
        return now >= open && now < close
    }
}

public enum Countdown {
    /// "0:42", "12:05", "1:02:10" for an absolute number of seconds.
    public static func clock(_ seconds: TimeInterval) -> String {
        let s = Int(abs(seconds).rounded(.down))
        let (h, m, sec) = (s / 3600, (s % 3600) / 60, s % 60)
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, sec)
            : String(format: "%d:%02d", m, sec)
    }

    /// "now", "45s", "12m", "2h 5m" for menu-bar sized labels.
    public static func short(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded(.up))
        if s <= 0 { return "now" }
        if s < 60 { return "\(s)s" }
        let m = Int((Double(s) / 60).rounded(.up))
        if m < 60 { return "\(m)m" }
        return m % 60 == 0 ? "\(m / 60)h" : "\(m / 60)h \(m % 60)m"
    }
}
