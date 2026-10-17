// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI
import WidgetKit

struct CalendarWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "VorssaintCalendar", provider: SnapshotProvider(moments: Self.moments)) { entry in
            CalendarWidgetView(entry: entry)
        }
        .configurationDisplayName("Calendar")
        .description("The next event, or the whole day.")
        .supportedFamilies([.systemSmall, .systemLarge])
    }
}

extension CalendarWidget {
    /// Each start and end, and midnight, when the day's list turns over.
    static func moments(_ snapshot: WidgetSnapshot, _ now: Date) -> [Date] {
        var result = WidgetAgenda.boundaries(snapshot.agenda?.events ?? [], now: now, limit: 12)
        if let midnight = Calendar.current.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0),
                                                    matchingPolicy: .nextTime) {
            result.append(midnight)
        }
        return result
    }
}

struct CalendarWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    private var calendar: Calendar { .current }

    var body: some View {
        Group {
            if let agenda = entry.snapshot?.agenda {
                if !agenda.accessGranted {
                    WidgetPlaceholder(entry: entry, detail: "Allow calendar access in Vorssaint")
                } else if family == .systemSmall {
                    small(agenda)
                } else {
                    large(agenda)
                }
            } else {
                WidgetPlaceholder(entry: entry)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: Small: the next event

    private func small(_ agenda: WidgetSnapshot.Agenda) -> some View {
        let today = WidgetAgenda.dayEvents(agenda.events, day: entry.date, calendar: calendar)
        let focus = WidgetAgenda.focus(today, now: entry.date)
        return VStack(alignment: .leading, spacing: 4) {
            WidgetHeader(title: focus?.ongoing == true ? "Now" : "Next", entry: entry)
            if let focus {
                Spacer(minLength: 2)
                HStack(spacing: 6) {
                    Capsule().fill(WidgetFormat.color(focus.event)).frame(width: 4, height: 16)
                    if focus.ongoing {
                        HStack(spacing: 3) {
                            Text("until")
                            Text(focus.event.end, style: .time)
                        }
                        .font(.system(size: 12, weight: .semibold))
                    } else {
                        Text(focus.event.start, style: .time)
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                title(focus.event)
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(3)
                Spacer(minLength: 0)
                if !focus.ongoing {
                    Text(focus.event.start, style: .relative)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    subtitle(focus.event)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                Spacer(minLength: 0)
                Group {
                    if today.isEmpty {
                        Text("No events today")
                    } else {
                        Text("Nothing else today")
                    }
                }
                .font(.system(size: 15, weight: .semibold))
                tomorrowLine(agenda)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Large: the day

    private func large(_ agenda: WidgetSnapshot.Agenda) -> some View {
        let today = WidgetAgenda.dayEvents(agenda.events, day: entry.date, calendar: calendar)
        let shown = Array(today.prefix(Self.maxRows))
        return VStack(alignment: .leading, spacing: 10) {
            WidgetHeader(title: "Calendar", entry: entry)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(entry.date, format: .dateTime.day())
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.red)
                VStack(alignment: .leading, spacing: 0) {
                    Text(entry.date, format: .dateTime.weekday(.wide))
                        .font(.system(size: 13, weight: .semibold))
                    Text(entry.date, format: .dateTime.month(.wide))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            weekStrip(agenda)
            if today.isEmpty {
                Spacer(minLength: 0)
                Text("No events today")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer(minLength: 0)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(shown.enumerated()), id: \.offset) { _, event in
                        row(event)
                    }
                    if today.count > shown.count {
                        Text("+\(today.count - shown.count) more")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            tomorrowLine(agenda)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private static let maxRows = 5

    private func row(_ event: WidgetSnapshot.AgendaEvent) -> some View {
        let past = WidgetAgenda.isPast(event, now: entry.date)
        let ongoing = !event.allDay && event.start <= entry.date && entry.date < event.end
        return HStack(spacing: 10) {
            Capsule().fill(WidgetFormat.color(event)).frame(width: 4, height: 30)
            VStack(alignment: .leading, spacing: 0) {
                if event.allDay {
                    Text("All day")
                } else {
                    Text(event.start, style: .time)
                    Text(event.end, style: .time)
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .frame(width: 44, alignment: .leading)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    title(event).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    if ongoing {
                        Text("· now").font(.system(size: 11, weight: .semibold)).foregroundStyle(.red)
                    }
                }
                subtitle(event)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .opacity(past ? 0.45 : 1)
    }

    /// The days of this week, today marked and busy days dotted.
    private func weekStrip(_ agenda: WidgetSnapshot.Agenda) -> some View {
        let days = WidgetAgenda.weekDays(containing: entry.date, calendar: calendar)
        return HStack(spacing: 2) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                let isToday = calendar.isDate(day, inSameDayAs: entry.date)
                let busy = !WidgetAgenda.dayEvents(agenda.events, day: day, calendar: calendar).isEmpty
                VStack(spacing: 1) {
                    Text(day, format: .dateTime.weekday(.narrow))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(day, format: .dateTime.day())
                        .font(.system(size: 12, weight: isToday ? .bold : .regular))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 2)
                        .background(isToday ? Color.red : Color.clear, in: RoundedRectangle(cornerRadius: 7))
                        .foregroundStyle(isToday ? Color.white : Color.primary)
                    Circle()
                        .fill(busy ? Color.secondary : Color.clear)
                        .frame(width: 4, height: 4)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: Pieces

    /// The title, or "Busy" when the person keeps titles off the desk.
    @ViewBuilder
    private func title(_ event: WidgetSnapshot.AgendaEvent) -> some View {
        if event.title.isEmpty {
            Text("Busy")
        } else {
            Text(event.title)
        }
    }

    /// The place, else the calendar's name.
    @ViewBuilder
    private func subtitle(_ event: WidgetSnapshot.AgendaEvent) -> some View {
        if !event.location.isEmpty {
            Text(event.location)
        } else {
            Text(event.calendarName)
        }
    }

    @ViewBuilder
    private func tomorrowLine(_ agenda: WidgetSnapshot.Agenda) -> some View {
        let tomorrow = WidgetAgenda.tomorrow(agenda.events, now: entry.date, calendar: calendar)
        if tomorrow.count == 0 {
            Text("Nothing tomorrow")
        } else if let first = tomorrow.firstStart {
            HStack(spacing: 4) {
                Text("Tomorrow: \(tomorrow.count), first at")
                Text(first, style: .time)
            }
        } else {
            Text("Tomorrow: \(tomorrow.count)")
        }
    }
}
