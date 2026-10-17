// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// What the calendar widgets lead with and when their picture changes, plus
/// how little of the calendar the shared file carries: text only for the two
/// days a widget lists, none at all when the person keeps titles off.
enum WidgetAgendaTests {
    private static var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 1
        return calendar
    }()

    /// Saturday 17 Oct 2026, 14:32 UTC.
    private static let now = calendar.date(from: DateComponents(
        year: 2026, month: 10, day: 17, hour: 14, minute: 32))!

    private static func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    private static func event(_ title: String, _ start: Date, _ end: Date, allDay: Bool = false)
        -> WidgetSnapshot.AgendaEvent {
        WidgetSnapshot.AgendaEvent(title: title, calendarName: "Work", location: "Room 1",
                                   start: start, end: end, allDay: allDay,
                                   red: 0.2, green: 0.4, blue: 0.9)
    }

    static func run(_ suite: TestSuite) {
        day(suite)
        focus(suite)
        moments(suite)
        week(suite)
        shared(suite)
    }

    private static func day(_ suite: TestSuite) {
        let events = [
            event("Dinner", at(17, 19), at(17, 21)),
            event("Holiday", at(17, 0), at(18, 0), allDay: true),
            event("Standup", at(17, 9), at(17, 9, 15)),
            event("Night shift", at(17, 22), at(18, 6)),
            event("Tomorrow only", at(18, 10), at(18, 11)),
        ]
        let today = WidgetAgenda.dayEvents(events, day: now, calendar: calendar)
        suite.expect(today.map(\.title) == ["Holiday", "Standup", "Dinner", "Night shift"],
                     "all-day first, then by start, tomorrow's left out: \(today.map(\.title))")
        let tomorrow = WidgetAgenda.dayEvents(events, day: at(18, 12), calendar: calendar)
        suite.expect(tomorrow.map(\.title) == ["Night shift", "Tomorrow only"],
                     "an event running past midnight shows on both days: \(tomorrow.map(\.title))")
        suite.expect(WidgetAgenda.dayEvents([], day: now, calendar: calendar).isEmpty, "no events, no rows")
    }

    private static func focus(_ suite: TestSuite) {
        let events = [
            event("Later", at(17, 18), at(17, 19)),
            event("Long", at(17, 13), at(17, 16)),
            event("Short", at(17, 14), at(17, 15)),
            event("Holiday", at(17, 0), at(18, 0), allDay: true),
            event("Over", at(17, 9), at(17, 10)),
        ]
        let current = WidgetAgenda.focus(events, now: now)
        suite.expect(current?.event.title == "Short" && current?.ongoing == true,
                     "of the events under way the one ending first leads, got \(current?.event.title ?? "none")")

        let free = WidgetAgenda.focus(events, now: at(17, 16, 30))
        suite.expect(free?.event.title == "Later" && free?.ongoing == false,
                     "with nothing under way the next to start leads, got \(free?.event.title ?? "none")")
        suite.expect(WidgetAgenda.focus(events, now: at(17, 20)) == nil,
                     "nothing leads once the day's events are over, and an all-day event never leads")
        suite.expect(WidgetAgenda.focus([events[3]], now: now) == nil, "an all-day event alone never leads")
        suite.expect(WidgetAgenda.focus(events, now: at(17, 15))?.event.title == "Long",
                     "an event ending exactly now is over")
    }

    private static func moments(_ suite: TestSuite) {
        let events = [
            event("A", at(17, 15), at(17, 16)),
            event("B", at(17, 16), at(17, 17)),
            event("Past", at(17, 9), at(17, 10)),
            event("Holiday", at(17, 0), at(18, 0), allDay: true),
        ]
        let all = WidgetAgenda.boundaries(events, now: now, limit: 10)
        suite.expect(all == [at(17, 15), at(17, 16), at(17, 17)],
                     "each start and end after now, once each, in order, all-day ignored: \(all)")
        suite.expect(WidgetAgenda.boundaries(events, now: now, limit: 2).count == 2, "the limit caps the entries")
        suite.expect(WidgetAgenda.boundaries(events, now: now, limit: 0).isEmpty, "a zero limit is empty")

        let next = WidgetAgenda.tomorrow([event("Morning", at(18, 10), at(18, 11)),
                                          event("Holiday", at(18, 0), at(19, 0), allDay: true),
                                          event("Today", at(17, 18), at(17, 19))],
                                         now: now, calendar: calendar)
        suite.expect(next.count == 2 && next.firstStart == at(18, 10),
                     "tomorrow counts its events and names the first timed start: \(next)")
        suite.expect(WidgetAgenda.tomorrow([], now: now, calendar: calendar).count == 0, "an empty tomorrow")
        suite.expect(WidgetAgenda.isPast(events[2], now: now) && !WidgetAgenda.isPast(events[3], now: now),
                     "a finished event is past; an all-day one never is")
    }

    private static func week(_ suite: TestSuite) {
        let sundayFirst = WidgetAgenda.weekDays(containing: now, calendar: calendar)
        suite.expect(sundayFirst.count == 7 && calendar.component(.day, from: sundayFirst[0]) == 11
                         && calendar.component(.day, from: sundayFirst[6]) == 17,
                     "a Sunday-first week holding Saturday the 17th runs 11 to 17")
        var monday = calendar
        monday.firstWeekday = 2
        let mondayFirst = WidgetAgenda.weekDays(containing: now, calendar: monday)
        suite.expect(mondayFirst.count == 7 && monday.component(.day, from: mondayFirst[0]) == 12
                         && monday.component(.day, from: mondayFirst[6]) == 18,
                     "a Monday-first week holding the same day runs 12 to 18")
    }

    private static func shared(_ suite: TestSuite) {
        func input(_ title: String, _ start: Date, _ end: Date) -> WidgetSnapshotInputs.AgendaEvent {
            .init(title: title, calendarName: "Work", location: "Room 1", start: start, end: end,
                  allDay: false, red: 2, green: -1, blue: .nan)
        }
        var inputs = WidgetSnapshotInputs()
        suite.expect(WidgetSnapshotBuilder.build(inputs, now: now, calendar: calendar).agenda == nil,
                     "a calendar never read leaves no agenda section")
        inputs.agendaAccessGranted = false
        inputs.agendaEvents = [input("Secret", at(17, 18), at(17, 19))]
        let denied = WidgetSnapshotBuilder.build(inputs, now: now, calendar: calendar).agenda
        suite.expect(denied == WidgetSnapshot.Agenda(accessGranted: false),
                     "without calendar access the file says so and carries no event")

        inputs.agendaAccessGranted = true
        inputs.agendaEvents = [
            input("Today", at(17, 18), at(17, 19)),
            input("Tomorrow", at(18, 10), at(18, 11)),
            input("Next week", at(22, 10), at(22, 11)),
            input("Broken", at(17, 20), at(17, 19)),
        ]
        let events = WidgetSnapshotBuilder.build(inputs, now: now, calendar: calendar).agenda?.events ?? []
        suite.expect(events.map(\.title) == ["Today", "Tomorrow", ""],
                     "text goes out for today and tomorrow only, and an event ending before it starts is dropped: \(events.map(\.title))")
        suite.expect(events.last?.location == "" && events.first?.location == "Room 1",
                     "a place goes out under the same rule as a title")
        suite.expect(events.first.map { $0.red == 1 && $0.green == 0 && $0.blue == 0 } == true,
                     "calendar colours are held to 0...1 and a broken one to 0")

        inputs.showsEventTitles = false
        let hidden = WidgetSnapshotBuilder.build(inputs, now: now, calendar: calendar).agenda?.events ?? []
        suite.expect(!hidden.isEmpty && hidden.allSatisfy { $0.title.isEmpty && $0.location.isEmpty },
                     "with titles off no title or place reaches the file")
        let encoded = (try? WidgetSnapshotStore.encode(WidgetSnapshotBuilder.build(inputs, now: now, calendar: calendar)))
            .flatMap { String(data: $0, encoding: .utf8) } ?? ""
        suite.expect(!encoded.contains("Today") && !encoded.contains("Room 1"),
                     "with titles off nothing of an event's text is in the encoded file")

        inputs.showsEventTitles = true
        inputs.agendaEvents = (0..<100).map { input("E\($0)", at(17, 15), at(17, 16)) }
        suite.expect(WidgetSnapshotBuilder.build(inputs, now: now, calendar: calendar).agenda?.events.count
                         == WidgetSnapshotBuilder.maxAgendaEvents,
                     "the file carries at most \(WidgetSnapshotBuilder.maxAgendaEvents) events")

        var throttle = WidgetSnapshotThrottle()
        inputs.agendaEvents = [input("One", at(17, 18), at(17, 19))]
        _ = throttle.shouldWrite(WidgetSnapshotBuilder.build(inputs, now: now, calendar: calendar), now: now)
        inputs.agendaEvents = [input("One", at(17, 18), at(17, 20))]
        suite.expect(throttle.shouldWrite(WidgetSnapshotBuilder.build(inputs, now: now, calendar: calendar),
                                          now: now.addingTimeInterval(5)),
                     "an edited event reaches the desk without waiting for the interval")
    }
}
