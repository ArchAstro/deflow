import XCTest
@testable import DeflowCore

final class MeetingLinkTests: XCTestCase {
    func testZoomLinkInNotesWithPasscode() throws {
        let notes = """
        Calvin is inviting you to a scheduled Zoom meeting.
        Join Zoom Meeting
        https://acme.zoom.us/j/84512345678?pwd=QWxhZGRpbjpvcGVu.1
        Meeting ID: 845 1234 5678
        Passcode: 481516
        """
        let link = try XCTUnwrap(MeetingLink.find(in: [nil, "Zoom", notes]))
        XCTAssertEqual(link.provider, .zoom)
        XCTAssertEqual(link.meetingID, "845 1234 5678")
        XCTAssertEqual(link.passcode, "481516")
        XCTAssertEqual(
            link.nativeURL?.absoluteString,
            "zoommtg://acme.zoom.us/join?action=join&confno=84512345678&pwd=QWxhZGRpbjpvcGVu.1"
        )
    }

    func testGoogleMeetInHTMLNotes() throws {
        let notes = #"<p>Join: <a href="https://meet.google.com/abc-defg-hij?authuser=0&amp;hs=1">Meet</a>.</p>"#
        let link = try XCTUnwrap(MeetingLink.find(in: [notes]))
        XCTAssertEqual(link.provider, .meet)
        XCTAssertEqual(link.meetingID, "abc-defg-hij")
        XCTAssertEqual(link.url.query, "authuser=0&hs=1")
        XCTAssertNil(link.nativeURL)
    }

    func testKnownProviderBeatsGenericAndUnrelatedLinks() throws {
        let notes = "Agenda: https://docs.google.com/document/d/1 backup https://whereby.com/acme, main https://teams.microsoft.com/l/meetup-join/19%3ameeting_x/0."
        XCTAssertEqual(MeetingLink.find(in: [notes])?.provider, .teams)
        XCTAssertEqual(MeetingLink.find(in: ["https://whereby.com/acme"])?.provider, .other)
    }

    func testNoLink() {
        XCTAssertNil(MeetingLink.find(in: [nil, "Blue Bottle, 66 Mint St", "see https://zoom.us/pricing and https://example.com"]))
        XCTAssertNil(MeetingLink.find(in: []))
    }

    func testTrailingPunctuationStripped() {
        XCTAssertEqual(MeetingLink.find(in: ["Join (https://zoom.us/j/123456789)."])?.url.absoluteString,
                       "https://zoom.us/j/123456789")
    }
}

final class TriggerPolicyTests: XCTestCase {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    func event(minutes: Double = 30) -> MeetingEvent {
        MeetingEvent(id: "e", title: "t", start: start, end: start.addingTimeInterval(minutes * 60), calendarName: "c")
    }

    func testWindow() {
        let p = TriggerPolicy(lead: 60)
        XCTAssertFalse(p.isDue(event(), now: start.addingTimeInterval(-61)))
        XCTAssertTrue(p.isDue(event(), now: start.addingTimeInterval(-60)))
        XCTAssertTrue(p.isDue(event(), now: start.addingTimeInterval(599)))
        XCTAssertFalse(p.isDue(event(), now: start.addingTimeInterval(600)))
    }

    func testShortAndZeroLengthEventsStillFire() {
        let p = TriggerPolicy(lead: 0)
        XCTAssertTrue(p.isDue(event(minutes: 0), now: start.addingTimeInterval(30)))
        XCTAssertFalse(p.isDue(event(minutes: 5), now: start.addingTimeInterval(301)))
    }
}

final class CountdownTests: XCTestCase {
    func testClock() {
        XCTAssertEqual(Countdown.clock(42.9), "0:42")
        XCTAssertEqual(Countdown.clock(-134), "2:14")
        XCTAssertEqual(Countdown.clock(3730), "1:02:10")
    }

    func testShort() {
        XCTAssertEqual(Countdown.short(-5), "now")
        XCTAssertEqual(Countdown.short(45), "45s")
        XCTAssertEqual(Countdown.short(61), "2m")
        XCTAssertEqual(Countdown.short(7500), "2h 5m")
    }
}
