import Foundation

/// A video-call link pulled out of a calendar event's URL, location or notes.
public struct MeetingLink: Equatable, Sendable {
    public enum Provider: String, Sendable {
        case zoom = "Zoom"
        case meet = "Google Meet"
        case teams = "Microsoft Teams"
        case webex = "Webex"
        case other = "Video call"
    }

    public let provider: Provider
    public let url: URL
    public let meetingID: String?
    public let passcode: String?

    /// Deep link that opens the desktop client directly (Zoom only), skipping the browser hop.
    public var nativeURL: URL? {
        guard provider == .zoom, let host = url.host, let id = meetingID else { return nil }
        var c = URLComponents()
        c.scheme = "zoommtg"
        c.host = host
        c.path = "/join"
        var items = [
            URLQueryItem(name: "action", value: "join"),
            URLQueryItem(name: "confno", value: id.filter(\.isNumber)),
        ]
        if let pwd = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "pwd" })?.value {
            items.append(URLQueryItem(name: "pwd", value: pwd))
        }
        c.queryItems = items
        return c.url
    }

    /// Searches the given texts in order and returns the best call link.
    /// Known providers win over generic ones; earlier texts win over later ones.
    public static func find(in texts: [String?]) -> MeetingLink? {
        let joined = texts.compactMap { $0 }.joined(separator: "\n")
            .replacingOccurrences(of: "&amp;", with: "&")
        guard !joined.isEmpty else { return nil }

        var fallback: MeetingLink?
        for url in urls(in: joined) {
            guard let provider = classify(url) else { continue }
            let link = MeetingLink(
                provider: provider,
                url: url,
                meetingID: meetingID(for: provider, url: url),
                passcode: passcode(in: joined)
            )
            if provider != .other { return link }
            if fallback == nil { fallback = link }
        }
        return fallback
    }

    // MARK: - Parsing

    static func urls(in text: String) -> [URL] {
        let pattern = #"https?://[^\s<>"'\)\]]+"#
        guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap {
            var s = ns.substring(with: $0.range)
            while let last = s.last, ".,;:!?".contains(last) { s.removeLast() }
            return URL(string: s)
        }
    }

    static func classify(_ url: URL) -> Provider? {
        guard let host = url.host?.lowercased() else { return nil }
        let path = url.path.lowercased()
        func isHost(_ d: String) -> Bool { host == d || host.hasSuffix("." + d) }

        if isHost("zoom.us") || isHost("zoomgov.com") || isHost("zoom.com") {
            return ["/j/", "/w/", "/my/", "/s/"].contains(where: path.contains) ? .zoom : nil
        }
        if host == "meet.google.com" { return path.count > 1 ? .meet : nil }
        if isHost("teams.microsoft.com") || isHost("teams.live.com") {
            return path.contains("meet") ? .teams : nil
        }
        if isHost("webex.com") { return .webex }
        let generic = ["whereby.com", "around.co", "meet.jit.si", "gotomeeting.com", "gotomeet.me",
                       "chime.aws", "bluejeans.com", "tuple.app", "pop.com", "riverside.fm", "cal.com",
                       "daily.co", "huddle.team", "app.slack.com"]
        return generic.contains(where: isHost) ? .other : nil
    }

    static func meetingID(for provider: Provider, url: URL) -> String? {
        let parts = url.pathComponents.filter { $0 != "/" }
        switch provider {
        case .zoom:
            guard let i = parts.firstIndex(where: { ["j", "w", "s"].contains($0) }),
                  parts.indices.contains(i + 1) else { return nil }
            let digits = parts[i + 1].filter(\.isNumber)
            return digits.isEmpty ? nil : groupDigits(digits)
        case .meet:
            return parts.first
        default:
            return nil
        }
    }

    static func groupDigits(_ d: String) -> String {
        let sizes: [Int]
        switch d.count {
        case 9: sizes = [3, 3, 3]
        case 10: sizes = [3, 3, 4]
        case 11: sizes = [3, 4, 4]
        default: return d
        }
        var out: [String] = []
        var rest = Substring(d)
        for n in sizes {
            out.append(String(rest.prefix(n)))
            rest = rest.dropFirst(n)
        }
        return out.joined(separator: " ")
    }

    static func passcode(in text: String) -> String? {
        let pattern = #"(?i)\b(?:passcode|password|pin)\s*[:：]\s*([A-Za-z0-9!@#$%^&*._-]{3,32})"#
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = text as NSString
        guard let m = re.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return ns.substring(with: m.range(at: 1))
    }
}
