// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// What the calendar widgets decide from a snapshot's events: which belong to
/// a day, which one a small widget leads with, and when the picture changes.
///
/// Pure and Foundation-only because the extension compiles it too. Every
/// function takes the moment to judge by: a widget draws entries for future
/// moments, so "now" is whatever entry is being drawn, never the clock.
enum WidgetAgenda {
    typealias Event = WidgetSnapshot.AgendaEvent

    /// Events that touch `day`: all-day ones first, then by start. An event
    /// running past midnight shows on both days.
    static func dayEvents(_ events: [Event], day: Date, calendar: Calendar) -> [Event] {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        return events
            .filter { $0.start < dayEnd && $0.end > dayStart }
            .sorted { lhs, rhs in
                if lhs.allDay != rhs.allDay { return lhs.allDay }
                if lhs.start != rhs.start { return lhs.start < rhs.start }
                return lhs.end < rhs.end
            }
    }

    /// The event a small widget leads with: one under way (the one ending
    /// first) or else the next to start. All-day events never lead; they say
    /// nothing about what is next.
    static func focus(_ events: [Event], now: Date) -> (event: Event, ongoing: Bool)? {
        let timed = events.filter { !$0.allDay && $0.end > now }
        if let current = timed.filter({ $0.start <= now }).min(by: { $0.end < $1.end }) {
            return (current, true)
        }
        if let next = timed.filter({ $0.start > now }).min(by: { $0.start < $1.start }) {
            return (next, false)
        }
        return nil
    }

    /// The moments after `now` when the drawing changes: an event starts or
    /// ends. The widget asks for one entry at each, so "now" and "past" move
    /// without the app running.
    static func boundaries(_ events: [Event], now: Date, limit: Int) -> [Date] {
        guard limit > 0 else { return [] }
        let moments = events.filter { !$0.allDay }.flatMap { [$0.start, $0.end] }.filter { $0 > now }
        return Array(Set(moments).sorted().prefix(limit))
    }

    /// How many timed or all-day events tomorrow holds and when the first
    /// timed one starts.
    static func tomorrow(_ events: [Event], now: Date, calendar: Calendar) -> (count: Int, firstStart: Date?) {
        guard let day = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else {
            return (0, nil)
        }
        let list = dayEvents(events, day: day, calendar: calendar)
        return (list.count, list.first { !$0.allDay }?.start)
    }

    /// The seven days of the week holding `now`, in the calendar's own order
    /// (Sunday or Monday first), for the strip above the day's events.
    static func weekDays(containing now: Date, calendar: Calendar) -> [Date] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: week.start) }
    }

    /// The first moment of the month holding `date`.
    static func startOfMonth(_ date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    /// The month `offset` months away from the one holding `date`.
    static func month(_ date: Date, offset: Int, calendar: Calendar) -> Date {
        let start = startOfMonth(date, calendar: calendar)
        return calendar.date(byAdding: .month, value: offset, to: start) ?? start
    }

    /// The 42 days a month grid shows: six whole weeks, starting on the
    /// calendar's first weekday on or before the 1st, so every month (even a
    /// February starting on a Monday) has the same shape and the grid never
    /// changes height while navigating.
    static func monthGrid(containing date: Date, calendar: Calendar) -> [Date] {
        let first = startOfMonth(date, calendar: calendar)
        let weekday = calendar.component(.weekday, from: first)
        let lead = (weekday - calendar.firstWeekday + 7) % 7
        guard let gridStart = calendar.date(byAdding: .day, value: -lead, to: first) else { return [] }
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: gridStart) }
    }

    /// The span a month grid covers, for reading its events in one go.
    static func gridInterval(containing date: Date, calendar: Calendar) -> DateInterval? {
        let days = monthGrid(containing: date, calendar: calendar)
        guard let first = days.first, let last = days.last,
              let end = calendar.date(byAdding: .day, value: 1, to: last) else { return nil }
        return DateInterval(start: first, end: end)
    }

    /// Whether `event` is over at `now`, for dimming it in the day list.
    static func isPast(_ event: Event, now: Date) -> Bool {
        !event.allDay && event.end <= now
    }
}
