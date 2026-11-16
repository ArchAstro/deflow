import XCTest
@testable import DeflowCore

final class GoogleCalendarTests: XCTestCase {
    func testCalendarsKeepOnlyOwnedAndSelected() throws {
        let json = """
        {"items":[
          {"id":"me@acme.com","summary":"me@acme.com","summaryOverride":"Work","accessRole":"owner","primary":true,"selected":true},
          {"id":"side@group.calendar.google.com","summary":"Side","accessRole":"owner","selected":true},
          {"id":"off@group.calendar.google.com","summary":"Unticked","accessRole":"owner"},
          {"id":"coworker@acme.com","summary":"Dana","accessRole":"reader","selected":true},
          {"id":"holidays","summary":"Holidays","accessRole":"reader","selected":true}
        ]}
        """
        let cals = try GoogleCalendar.decodeCalendars(Data(json.utf8))
        XCTAssertEqual(cals.map(\.name), ["Work", "Side"])
        XCTAssertEqual(cals.first?.isPrimary, true)
    }

    func testEventsMappingAndFiltering() throws {
        let json = """
        {"items":[
          {"id":"1","iCalUID":"uid1","status":"confirmed","summary":"Acme pilot kickoff",
           "start":{"dateTime":"2026-11-16T15:00:00-08:00"},"end":{"dateTime":"2026-11-16T15:30:00-08:00"},
           "hangoutLink":"https://meet.google.com/abc-defg-hij",
           "attendees":[
             {"email":"me@acme.com","self":true,"responseStatus":"accepted"},
             {"email":"dana@customer.com","displayName":"Dana Whitfield","responseStatus":"accepted"},
             {"email":"luis@customer.com","responseStatus":"needsAction"},
             {"email":"room-4@resource.calendar.google.com","resource":true}],
           "conferenceData":{"entryPoints":[
             {"entryPointType":"phone","uri":"tel:+1-555"},
             {"entryPointType":"video","uri":"https://meet.google.com/abc-defg-hij"}]}},
          {"id":"2","summary":"Zoom via add-on","location":"https://acme.zoom.us/j/84512345678",
           "start":{"dateTime":"2026-11-16T23:00:00Z"},"end":{"dateTime":"2026-11-16T23:30:00Z"},
           "conferenceData":{"entryPoints":[
             {"entryPointType":"video","uri":"https://acme.zoom.us/j/84512345678?pwd=x","passcode":"481516"}]}},
          {"id":"3","summary":"Declined","start":{"dateTime":"2026-11-16T16:00:00-08:00"},"end":{"dateTime":"2026-11-16T16:30:00-08:00"},
           "attendees":[{"email":"me@acme.com","self":true,"responseStatus":"declined"}]},
          {"id":"4","status":"cancelled"},
          {"id":"5","summary":"Conference day","start":{"date":"2026-11-16"},"end":{"date":"2026-11-17"}},
          {"id":"6","summary":"OOO","eventType":"outOfOffice","start":{"dateTime":"2026-11-16T09:00:00-08:00"},"end":{"dateTime":"2026-11-16T17:00:00-08:00"}},
          {"id":"7","start":{"dateTime":"2026-11-16T17:00:00.000-08:00"},"end":{"dateTime":"2026-11-16T17:30:00.000-08:00"}}
        ]}
        """
        let events = try GoogleCalendar.decodeEvents(Data(json.utf8), calendarName: "Work")
        XCTAssertEqual(events.map(\.title), ["Acme pilot kickoff", "Zoom via add-on", "Busy"])

        let meet = events[0]
        XCTAssertEqual(meet.start, Date(timeIntervalSince1970: 1_794_870_000))
        XCTAssertEqual(meet.end.timeIntervalSince(meet.start), 1800)
        XCTAssertEqual(meet.attendees, ["Dana Whitfield", "luis@customer.com"])
        XCTAssertEqual(meet.link?.provider, .meet)
        XCTAssertEqual(meet.link?.meetingID, "abc-defg-hij")
        XCTAssertEqual(meet.calendarName, "Work")
        XCTAssertTrue(meet.id.hasPrefix("uid1|"))

        let zoom = events[1]
        XCTAssertEqual(zoom.link?.provider, .zoom)
        XCTAssertEqual(zoom.link?.passcode, "481516")
        XCTAssertNil(zoom.location, "a URL-only location is not shown as a place")
        XCTAssertNil(events[2].link)
    }

    func testEmptyResponses() throws {
        XCTAssertEqual(try GoogleCalendar.decodeEvents(Data("{}".utf8), calendarName: "x"), [])
        XCTAssertEqual(try GoogleCalendar.decodeCalendars(Data("{}".utf8)), [])
    }
}
