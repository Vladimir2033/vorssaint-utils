// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// What the desktop cards draw from: the latest snapshot and the moment it is
/// drawn for, which moves on its own so "now" and "past" stay right between
/// readings.
@MainActor
final class DesktopWidgetsModel: ObservableObject {
    @Published var snapshot: WidgetSnapshot?
    @Published var now = Date()
}

/// One card: its content over a translucent rounded surface that follows the
/// system appearance.
struct DesktopWidgetRoot: View {
    let kind: DesktopWidgetKind
    @ObservedObject var model: DesktopWidgetsModel
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let strings = FeatureStrings.desktopWidgets(l10n.language)
        Group {
            switch kind {
            case .system:
                DesktopSystemCard(system: model.snapshot?.system, strings: strings, compact: false)
            case .systemCompact:
                DesktopSystemCard(system: model.snapshot?.system, strings: strings, compact: true)
            case .agenda:
                DesktopAgendaCard(agenda: model.snapshot?.agenda, now: model.now, strings: strings)
            case .nextEvent:
                DesktopNextEventCard(agenda: model.snapshot?.agenda, now: model.now, strings: strings)
            }
        }
        .padding(14)
        .frame(width: kind.size.width, height: kind.size.height, alignment: .topLeading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
    }
}

private enum DesktopWidgetFormat {
    static func bytes(_ count: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(min(count, UInt64(Int64.max))), countStyle: .file)
    }

    static func rate(_ bytesPerSecond: Double) -> String {
        bytes(UInt64(max(0, bytesPerSecond.isFinite ? bytesPerSecond : 0))) + "/s"
    }

    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func color(_ event: WidgetSnapshot.AgendaEvent) -> Color {
        Color(red: event.red, green: event.green, blue: event.blue)
    }
}

private struct DesktopWidgetHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - System

struct DesktopSystemCard: View {
    let system: WidgetSnapshot.System?
    let strings: DesktopWidgetsFeatureStrings
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DesktopWidgetHeader(title: compact ? strings.systemCompact : strings.system)
            if compact { small } else { medium }
        }
    }

    private var small: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ring(system?.cpuPercent, label: strings.cpu, tint: .accentColor)
                ring(system?.memoryPercent, label: strings.memory, tint: memoryTint)
            }
            Spacer(minLength: 0)
            HStack {
                if let celsius = system?.cpuTemperatureCelsius {
                    Text("\(celsius) °C").foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                if let free = system?.diskFreeBytes {
                    Text(DesktopWidgetFormat.bytes(free)).fontWeight(.semibold)
                }
            }
            .font(.system(size: 12))
        }
    }

    private func ring(_ percent: Int?, label: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            ZStack {
                Circle().stroke(Color.primary.opacity(0.12), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: Double(percent ?? 0) / 100)
                    .stroke(tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(percent.map { "\($0)" } ?? "–")
                    .font(.system(size: 14, weight: .semibold))
                    .monospacedDigit()
            }
            .frame(width: 58, height: 58)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var memoryTint: Color {
        switch system?.memoryPressure {
        case "warning": return .orange
        case "critical": return .red
        default: return .green
        }
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(system?.cpuPercent.map { "\($0)" } ?? "–")
                        .font(.system(size: 34, weight: .semibold))
                        .monospacedDigit()
                    Text("% " + strings.cpu)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                if let history = system?.cpuHistory, history.count >= 3 {
                    let average = Int((Double(history.reduce(0, +)) / Double(history.count)).rounded())
                    Text("\(strings.average) \(average)%")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                DesktopSparkline(values: system?.cpuHistory ?? [])
                    .frame(maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: 5) {
                row(strings.memory) {
                    HStack(spacing: 4) {
                        Text(system?.memoryPercent.map { "\($0)%" } ?? "–").fontWeight(.semibold)
                        pressureBadge
                    }
                }
                row(strings.temperature) {
                    Text(system?.cpuTemperatureCelsius.map { "\($0) °C" } ?? "–").fontWeight(.semibold)
                }
                row(strings.network) {
                    Text("↓ " + (system?.netDownBytesPerSec.map(DesktopWidgetFormat.rate) ?? "–")).fontWeight(.semibold)
                }
                row(strings.disk) {
                    Text(system?.diskFreeBytes.map(DesktopWidgetFormat.bytes) ?? "–").fontWeight(.semibold)
                }
                row(strings.gpu) {
                    Text(system?.gpuPercent.map { "\($0)%" } ?? "–").fontWeight(.semibold)
                }
            }
            .font(.system(size: 12))
            .frame(maxWidth: .infinity)
        }
    }

    private func row<Value: View>(_ title: String, @ViewBuilder value: () -> Value) -> some View {
        HStack(spacing: 6) {
            Text(title).foregroundStyle(.secondary).lineLimit(1)
            Spacer(minLength: 2)
            value().lineLimit(1).minimumScaleFactor(0.8)
        }
    }

    @ViewBuilder
    private var pressureBadge: some View {
        switch system?.memoryPressure {
        case "normal": badge(strings.pressureNormal, .green)
        case "warning": badge(strings.pressureWarning, .orange)
        case "critical": badge(strings.pressureCritical, .red)
        default: EmptyView()
        }
    }

    private func badge(_ text: String, _ tint: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 5))
    }
}

/// The CPU history as a line over a soft fill, newest point on the right.
struct DesktopSparkline: View {
    let values: [Int]

    var body: some View {
        GeometryReader { proxy in
            let points = positions(in: proxy.size)
            if points.count > 1, let first = points.first, let last = points.last {
                ZStack {
                    Path { path in
                        path.move(to: CGPoint(x: first.x, y: proxy.size.height))
                        for point in points { path.addLine(to: point) }
                        path.addLine(to: CGPoint(x: last.x, y: proxy.size.height))
                        path.closeSubpath()
                    }
                    .fill(Color.accentColor.opacity(0.18))
                    Path { path in
                        path.move(to: first)
                        for point in points.dropFirst() { path.addLine(to: point) }
                    }
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 5, height: 5)
                        .position(last)
                }
            }
        }
    }

    /// Scaled to the larger of 40% and the highest reading, so a quiet
    /// machine still draws a readable line instead of a flat one.
    private func positions(in size: CGSize) -> [CGPoint] {
        guard values.count > 1, size.width > 0, size.height > 0 else { return [] }
        let ceiling = Double(max(40, values.max() ?? 40))
        let step = size.width / CGFloat(values.count - 1)
        return values.enumerated().map { index, value in
            let fraction = min(1, max(0, Double(value) / ceiling))
            return CGPoint(x: CGFloat(index) * step, y: size.height - CGFloat(fraction) * (size.height - 6) - 3)
        }
    }
}

// MARK: - Calendar

private func tomorrowLine(_ agenda: WidgetSnapshot.Agenda, now: Date,
                          strings: DesktopWidgetsFeatureStrings) -> String {
    let tomorrow = WidgetAgenda.tomorrow(agenda.events, now: now, calendar: .current)
    if tomorrow.count == 0 { return strings.nothingTomorrow }
    if let first = tomorrow.firstStart {
        return String(format: strings.tomorrowFormat, tomorrow.count, DesktopWidgetFormat.time(first))
    }
    return String(format: strings.tomorrowCountFormat, tomorrow.count)
}

private func eventTitle(_ event: WidgetSnapshot.AgendaEvent, strings: DesktopWidgetsFeatureStrings) -> String {
    event.title.isEmpty ? strings.busy : event.title
}

private func eventSubtitle(_ event: WidgetSnapshot.AgendaEvent) -> String {
    event.location.isEmpty ? event.calendarName : event.location
}

/// What a calendar card says when it cannot show the calendar.
private struct DesktopCalendarPlaceholder: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading) {
            Spacer(minLength: 0)
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DesktopNextEventCard: View {
    let agenda: WidgetSnapshot.Agenda?
    let now: Date
    let strings: DesktopWidgetsFeatureStrings

    var body: some View {
        if let agenda, agenda.accessGranted {
            content(agenda)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                DesktopWidgetHeader(title: strings.nextEvent)
                DesktopCalendarPlaceholder(text: agenda == nil ? "–" : strings.noCalendarAccess)
            }
        }
    }

    private func content(_ agenda: WidgetSnapshot.Agenda) -> some View {
        let today = WidgetAgenda.dayEvents(agenda.events, day: now, calendar: .current)
        let focus = WidgetAgenda.focus(today, now: now)
        return VStack(alignment: .leading, spacing: 4) {
            DesktopWidgetHeader(title: focus?.ongoing == true ? strings.nowLabel : strings.nextLabel)
            if let focus {
                Spacer(minLength: 2)
                HStack(spacing: 6) {
                    Capsule().fill(DesktopWidgetFormat.color(focus.event)).frame(width: 4, height: 16)
                    Text(focus.ongoing
                         ? String(format: strings.untilFormat, DesktopWidgetFormat.time(focus.event.end))
                         : DesktopWidgetFormat.time(focus.event.start))
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(eventTitle(focus.event, strings: strings))
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(3)
                Spacer(minLength: 0)
                if focus.ongoing {
                    Text(eventSubtitle(focus.event))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(focus.event.start, style: .relative)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                Spacer(minLength: 0)
                Text(today.isEmpty ? strings.noEventsToday : strings.nothingElseToday)
                    .font(.system(size: 15, weight: .semibold))
                Text(tomorrowLine(agenda, now: now, strings: strings))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct DesktopAgendaCard: View {
    let agenda: WidgetSnapshot.Agenda?
    let now: Date
    let strings: DesktopWidgetsFeatureStrings

    private static let maxRows = 5
    private var calendar: Calendar { .current }

    var body: some View {
        if let agenda, agenda.accessGranted {
            content(agenda)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                DesktopWidgetHeader(title: strings.agenda)
                DesktopCalendarPlaceholder(text: agenda == nil ? "–" : strings.noCalendarAccess)
            }
        }
    }

    private func content(_ agenda: WidgetSnapshot.Agenda) -> some View {
        let today = WidgetAgenda.dayEvents(agenda.events, day: now, calendar: calendar)
        let shown = Array(today.prefix(Self.maxRows))
        return VStack(alignment: .leading, spacing: 10) {
            DesktopWidgetHeader(title: strings.agenda)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(now, format: .dateTime.day())
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.red)
                VStack(alignment: .leading, spacing: 0) {
                    Text(now, format: .dateTime.weekday(.wide))
                        .font(.system(size: 13, weight: .semibold))
                    Text(now, format: .dateTime.month(.wide))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            weekStrip(agenda)
            if today.isEmpty {
                Spacer(minLength: 0)
                Text(strings.noEventsToday)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer(minLength: 0)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(shown.enumerated()), id: \.offset) { _, event in
                        row(event)
                    }
                    if today.count > shown.count {
                        Text(String(format: strings.moreFormat, today.count - shown.count))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            Text(tomorrowLine(agenda, now: now, strings: strings))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private func row(_ event: WidgetSnapshot.AgendaEvent) -> some View {
        let past = WidgetAgenda.isPast(event, now: now)
        return HStack(spacing: 10) {
            Capsule().fill(DesktopWidgetFormat.color(event)).frame(width: 4, height: 30)
            VStack(alignment: .leading, spacing: 0) {
                if event.allDay {
                    Text(strings.allDay)
                } else {
                    Text(event.start, style: .time)
                    Text(event.end, style: .time)
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .frame(width: 52, alignment: .leading)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Text(eventTitle(event, strings: strings))
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    if !event.allDay, event.start <= now, now < event.end {
                        Circle().fill(Color.red).frame(width: 6, height: 6)
                    }
                }
                Text(eventSubtitle(event))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .opacity(past ? 0.45 : 1)
    }

    /// The days of this week, today marked and busy days dotted.
    private func weekStrip(_ agenda: WidgetSnapshot.Agenda) -> some View {
        let days = WidgetAgenda.weekDays(containing: now, calendar: calendar)
        return HStack(spacing: 2) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                let isToday = calendar.isDate(day, inSameDayAs: now)
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
}
