// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// What the desktop cards draw from: the latest snapshot and the moment it is
/// drawn for, which moves on its own so "now" and "past" stay right between
/// readings.
@MainActor
final class DesktopWidgetsModel: ObservableObject {
    @Published var snapshot: WidgetSnapshot?
    @Published var now = Date()
}

/// The month card's own state: which month it shows, the day picked and that
/// grid's events, read when the person moves to another month.
@MainActor
final class DesktopMonthModel: ObservableObject {
    @Published var month = WidgetAgenda.startOfMonth(Date(), calendar: .current)
    @Published var selected = Calendar.current.startOfDay(for: Date())
    @Published var events: [WidgetSnapshot.AgendaEvent] = []
    @Published var accessGranted: Bool?
}

/// The colours of the mockup: one per kind of reading, the same in every
/// card, so a glance across the desk finds CPU in blue and memory in green.
enum DesktopPalette {
    static let cpu = Color(red: 0.20, green: 0.47, blue: 0.95)
    static let memory = Color(red: 0.15, green: 0.70, blue: 0.40)
    static let gpu = Color(red: 0.10, green: 0.68, blue: 0.75)
    static let download = Color(red: 0.55, green: 0.36, blue: 0.95)
    static let upload = Color(red: 0.96, green: 0.56, blue: 0.16)
    static let warning = Color(red: 0.96, green: 0.56, blue: 0.16)
    static let critical = Color(red: 0.92, green: 0.26, blue: 0.27)
    static let today = Color(red: 0.92, green: 0.26, blue: 0.27)
    static let track = Color.primary.opacity(0.12)

    static func battery(_ percent: Int) -> Color {
        if percent <= 10 { return critical }
        if percent <= 20 { return warning }
        return memory
    }
}

/// Real frosted glass. SwiftUI's materials blend only with what is inside the
/// window, and a desktop card has nothing behind it but clear: they came out
/// as flat grey. An NSVisualEffectView blending behind the window blurs the
/// wallpaper, and `.active` keeps it vivid although the card is never key.
private struct DesktopGlass: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 22
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

/// One card: its content over the glass.
struct DesktopWidgetRoot: View {
    let kind: DesktopWidgetKind
    @ObservedObject var model: DesktopWidgetsModel
    @ObservedObject var month: DesktopMonthModel
    let actions: DesktopWidgetActions
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let strings = FeatureStrings.desktopWidgets(l10n.language)
        Group {
            switch kind {
            case .system:
                DesktopSystemCard(system: model.snapshot?.system, strings: strings)
            case .systemCompact:
                DesktopSystemCompactCard(system: model.snapshot?.system, strings: strings)
            case .systemDetailed:
                DesktopSystemDetailedCard(system: model.snapshot?.system, strings: strings)
            case .agenda:
                DesktopAgendaCard(agenda: model.snapshot?.agenda, now: model.now, strings: strings)
            case .nextEvent:
                DesktopNextEventCard(agenda: model.snapshot?.agenda, now: model.now, strings: strings)
            case .calendarMonth:
                DesktopMonthCard(model: month, now: model.now, strings: strings, actions: actions)
            case .worldClock:
                DesktopWorldClockCard(now: model.now, strings: strings)
            case .accessories:
                DesktopAccessoriesCard(power: model.snapshot?.power, strings: strings)
            case .weather:
                DesktopWeatherCard(strings: strings)
            }
        }
        .padding(14)
        .frame(width: kind.size.width, height: kind.size.height, alignment: .topLeading)
        .background(DesktopGlass())
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
    }
}

/// What the month card asks the service to do.
struct DesktopWidgetActions {
    var showMonth: @MainActor (Int) -> Void
    var showToday: @MainActor () -> Void
    var select: @MainActor (Date) -> Void
}

enum DesktopWidgetFormat {
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

struct DesktopWidgetHeader: View {
    let title: String
    var symbol: String?

    var body: some View {
        HStack(spacing: 5) {
            if let symbol {
                Image(systemName: symbol).font(.system(size: 10, weight: .semibold))
            }
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.4)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Charts

/// A reading's recent history: a line over a fill that fades down, a faint
/// middle guide and a dot on the newest value. `ceiling` nil scales to the
/// largest value seen (network); percentages pass 100 or a floor that keeps a
/// quiet machine from drawing a flat line.
struct DesktopSparkline: View {
    let values: [Double]
    let color: Color
    var ceiling: Double?
    var floorCeiling: Double = 0

    var body: some View {
        GeometryReader { proxy in
            let points = positions(in: proxy.size)
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: proxy.size.height / 2))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height / 2))
                }
                .stroke(Color.primary.opacity(0.07), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                if points.count > 1, let first = points.first, let last = points.last {
                    Path { path in
                        path.move(to: CGPoint(x: first.x, y: proxy.size.height))
                        for point in points { path.addLine(to: point) }
                        path.addLine(to: CGPoint(x: last.x, y: proxy.size.height))
                        path.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [color.opacity(0.38), color.opacity(0.02)],
                                         startPoint: .top, endPoint: .bottom))
                    Path { path in
                        path.move(to: first)
                        for point in points.dropFirst() { path.addLine(to: point) }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                    Circle()
                        .fill(color)
                        .frame(width: 5, height: 5)
                        .shadow(color: color.opacity(0.6), radius: 3)
                        .position(last)
                }
            }
        }
    }

    private func positions(in size: CGSize) -> [CGPoint] {
        let finite = values.filter(\.isFinite)
        guard finite.count > 1, size.width > 0, size.height > 0 else { return [] }
        let top = max(ceiling ?? (finite.max() ?? 1), floorCeiling, 0.000_001)
        let step = size.width / CGFloat(finite.count - 1)
        return finite.enumerated().map { index, value in
            let fraction = min(1, max(0, value / top))
            return CGPoint(x: CGFloat(index) * step, y: size.height - CGFloat(fraction) * (size.height - 6) - 3)
        }
    }
}

/// A percentage as a ring, the value in the middle.
struct DesktopRing<Center: View>: View {
    let fraction: Double
    let color: Color
    var lineWidth: CGFloat = 6
    @ViewBuilder let center: () -> Center

    var body: some View {
        ZStack {
            Circle().stroke(DesktopPalette.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(1, max(0, fraction)))
                .stroke(AngularGradient(colors: [color.opacity(0.75), color], center: .center),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            center()
        }
    }
}

/// A thin bar for a share of something, such as a full disk.
struct DesktopBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(DesktopPalette.track)
                Capsule()
                    .fill(LinearGradient(colors: [color.opacity(0.8), color], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(4, proxy.size.width * CGFloat(min(1, max(0, fraction)))))
            }
        }
        .frame(height: 6)
    }
}

// MARK: - System

private func memoryColor(_ pressure: String?) -> Color {
    switch pressure {
    case "warning": return DesktopPalette.warning
    case "critical": return DesktopPalette.critical
    default: return DesktopPalette.memory
    }
}

private func percentText(_ value: Int?) -> String { value.map { "\($0)" } ?? "–" }

private func diskUsed(_ system: WidgetSnapshot.System?) -> Double? {
    guard let free = system?.diskFreeBytes, let total = system?.diskTotalBytes, total > 0 else { return nil }
    return 1 - Double(free) / Double(total)
}

private struct PressureBadge: View {
    let pressure: String?
    let strings: DesktopWidgetsFeatureStrings

    var body: some View {
        let label: String? = {
            switch pressure {
            case "normal": return strings.pressureNormal
            case "warning": return strings.pressureWarning
            case "critical": return strings.pressureCritical
            default: return nil
            }
        }()
        if let label {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(memoryColor(pressure))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(memoryColor(pressure).opacity(0.18), in: RoundedRectangle(cornerRadius: 5))
        }
    }
}

struct DesktopSystemCompactCard: View {
    let system: WidgetSnapshot.System?
    let strings: DesktopWidgetsFeatureStrings

    var body: some View {
        VStack(spacing: 8) {
            DesktopWidgetHeader(title: strings.system, symbol: "cpu")
            HStack(spacing: 10) {
                gauge(system?.cpuPercent, label: strings.cpu, color: DesktopPalette.cpu)
                gauge(system?.memoryPercent, label: strings.memory, color: memoryColor(system?.memoryPressure))
            }
            Spacer(minLength: 0)
            HStack {
                if let celsius = system?.cpuTemperatureCelsius {
                    Label("\(celsius) °C", systemImage: "thermometer.medium")
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                if let free = system?.diskFreeBytes {
                    Text(DesktopWidgetFormat.bytes(free)).fontWeight(.semibold)
                }
            }
            .font(.system(size: 11))
        }
    }

    private func gauge(_ percent: Int?, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            DesktopRing(fraction: Double(percent ?? 0) / 100, color: color) {
                Text(percentText(percent))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(width: 60, height: 60)
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct DesktopSystemCard: View {
    let system: WidgetSnapshot.System?
    let strings: DesktopWidgetsFeatureStrings

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            DesktopWidgetHeader(title: strings.system, symbol: "cpu")
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(percentText(system?.cpuPercent))
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
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
                    DesktopSparkline(values: (system?.cpuHistory ?? []).map(Double.init),
                                     color: DesktopPalette.cpu, floorCeiling: 40)
                        .frame(maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(spacing: 6) {
                    row(strings.memory) {
                        HStack(spacing: 4) {
                            Text(system?.memoryPercent.map { "\($0)%" } ?? "–").fontWeight(.semibold)
                            PressureBadge(pressure: system?.memoryPressure, strings: strings)
                        }
                    }
                    row(strings.temperature) {
                        Text(system?.cpuTemperatureCelsius.map { "\($0) °C" } ?? "–").fontWeight(.semibold)
                    }
                    row(strings.network) {
                        Text("↓ " + (system?.netDownBytesPerSec.map(DesktopWidgetFormat.rate) ?? "–"))
                            .fontWeight(.semibold)
                            .foregroundStyle(DesktopPalette.download)
                    }
                    row(strings.disk) {
                        Text(system?.diskFreeBytes.map(DesktopWidgetFormat.bytes) ?? "–").fontWeight(.semibold)
                    }
                    if let used = diskUsed(system) {
                        DesktopBar(fraction: used, color: used > 0.9 ? DesktopPalette.warning : DesktopPalette.cpu)
                    }
                    row(strings.gpu) {
                        Text(system?.gpuPercent.map { "\($0)%" } ?? "–").fontWeight(.semibold)
                    }
                }
                .font(.system(size: 12))
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func row<Value: View>(_ title: String, @ViewBuilder value: () -> Value) -> some View {
        HStack(spacing: 6) {
            Text(title).foregroundStyle(.secondary).lineLimit(1)
            Spacer(minLength: 2)
            value().lineLimit(1).minimumScaleFactor(0.8)
        }
    }
}

/// The big System card: four live charts and the disk.
struct DesktopSystemDetailedCard: View {
    let system: WidgetSnapshot.System?
    let strings: DesktopWidgetsFeatureStrings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DesktopWidgetHeader(title: strings.systemDetailed, symbol: "waveform.path.ecg")
            HStack(spacing: 10) {
                tile(strings.cpu, value: system?.cpuPercent.map { "\($0)%" },
                     history: (system?.cpuHistory ?? []).map(Double.init), color: DesktopPalette.cpu, ceiling: 100)
                tile(strings.memory, value: system?.memoryPercent.map { "\($0)%" },
                     history: (system?.memoryHistory ?? []).map(Double.init),
                     color: memoryColor(system?.memoryPressure), ceiling: 100,
                     badge: PressureBadge(pressure: system?.memoryPressure, strings: strings))
            }
            HStack(spacing: 10) {
                networkTile
                tile(strings.gpu, value: system?.gpuPercent.map { "\($0)%" },
                     history: (system?.gpuHistory ?? []).map(Double.init), color: DesktopPalette.gpu, ceiling: 100)
            }
            HStack(spacing: 12) {
                Label(system?.cpuTemperatureCelsius.map { "\($0) °C" } ?? "–", systemImage: "thermometer.medium")
                    .font(.system(size: 12, weight: .semibold))
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(strings.disk).foregroundStyle(.secondary)
                        Spacer()
                        Text(system?.diskFreeBytes.map(DesktopWidgetFormat.bytes) ?? "–").fontWeight(.semibold)
                    }
                    .font(.system(size: 11))
                    DesktopBar(fraction: diskUsed(system) ?? 0,
                               color: (diskUsed(system) ?? 0) > 0.9 ? DesktopPalette.warning : DesktopPalette.cpu)
                }
            }
        }
    }

    private func tile(_ title: String, value: String?, history: [Double], color: Color, ceiling: Double,
                      badge: PressureBadge? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(title).font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                badge
            }
            Text(value ?? "–")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
            DesktopSparkline(values: history, color: color, ceiling: ceiling)
                .frame(maxHeight: .infinity)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var networkTile: some View {
        let down = system?.netDownHistory ?? []
        let up = system?.netUpHistory ?? []
        let ceiling = max(down.max() ?? 0, up.max() ?? 0, 1)
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Circle().fill(DesktopPalette.download).frame(width: 6, height: 6)
                Text(strings.network).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Text("↓ " + (system?.netDownBytesPerSec.map(DesktopWidgetFormat.rate) ?? "–"))
                    .foregroundStyle(DesktopPalette.download)
                Text("↑ " + (system?.netUpBytesPerSec.map(DesktopWidgetFormat.rate) ?? "–"))
                    .foregroundStyle(DesktopPalette.upload)
            }
            .font(.system(size: 12, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            ZStack {
                DesktopSparkline(values: down, color: DesktopPalette.download, ceiling: ceiling)
                DesktopSparkline(values: up, color: DesktopPalette.upload, ceiling: ceiling)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Calendar pieces

private func tomorrowLine(_ events: [WidgetSnapshot.AgendaEvent], now: Date,
                          strings: DesktopWidgetsFeatureStrings) -> String {
    let tomorrow = WidgetAgenda.tomorrow(events, now: now, calendar: .current)
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

/// One event in a list: its colour, its hours, title and place.
private struct DesktopEventRow: View {
    let event: WidgetSnapshot.AgendaEvent
    let now: Date
    let strings: DesktopWidgetsFeatureStrings

    var body: some View {
        let ongoing = !event.allDay && event.start <= now && now < event.end
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(DesktopWidgetFormat.color(event))
                .frame(width: 4, height: 30)
            VStack(alignment: .leading, spacing: 0) {
                if event.allDay {
                    Text(strings.allDay)
                } else {
                    Text(DesktopWidgetFormat.time(event.start))
                    Text(DesktopWidgetFormat.time(event.end))
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .frame(width: 52, alignment: .leading)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5) {
                    Text(eventTitle(event, strings: strings))
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    if ongoing {
                        Text(strings.nowLabel)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(DesktopPalette.today, in: Capsule())
                    }
                }
                Text(eventSubtitle(event))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(ongoing ? DesktopWidgetFormat.color(event).opacity(0.14) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 8))
        .opacity(WidgetAgenda.isPast(event, now: now) ? 0.45 : 1)
    }
}

private struct DesktopCalendarPlaceholder: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DesktopWidgetHeader(title: title, symbol: "calendar")
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
            DesktopCalendarPlaceholder(title: strings.nextEvent, text: agenda == nil ? "–" : strings.noCalendarAccess)
        }
    }

    private func content(_ agenda: WidgetSnapshot.Agenda) -> some View {
        let today = WidgetAgenda.dayEvents(agenda.events, day: now, calendar: .current)
        let focus = WidgetAgenda.focus(today, now: now)
        return VStack(alignment: .leading, spacing: 4) {
            DesktopWidgetHeader(title: focus?.ongoing == true ? strings.nowLabel : strings.nextLabel,
                                symbol: "calendar.badge.clock")
            if let focus {
                Spacer(minLength: 2)
                Text(focus.ongoing
                     ? String(format: strings.untilFormat, DesktopWidgetFormat.time(focus.event.end))
                     : DesktopWidgetFormat.time(focus.event.start))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DesktopWidgetFormat.color(focus.event))
                Text(eventTitle(focus.event, strings: strings))
                    .font(.system(size: 18, weight: .semibold))
                    .lineLimit(3)
                Spacer(minLength: 0)
                Group {
                    if focus.ongoing {
                        Text(eventSubtitle(focus.event))
                    } else {
                        Text(focus.event.start, style: .relative)
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            } else {
                Spacer(minLength: 0)
                Text(today.isEmpty ? strings.noEventsToday : strings.nothingElseToday)
                    .font(.system(size: 15, weight: .semibold))
                Text(tomorrowLine(agenda.events, now: now, strings: strings))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .overlay(alignment: .leading) {
            if let focus {
                RoundedRectangle(cornerRadius: 2)
                    .fill(DesktopWidgetFormat.color(focus.event))
                    .frame(width: 3)
                    .padding(.vertical, 24)
                    .offset(x: -9)
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
            DesktopCalendarPlaceholder(title: strings.agenda, text: agenda == nil ? "–" : strings.noCalendarAccess)
        }
    }

    private func content(_ agenda: WidgetSnapshot.Agenda) -> some View {
        let today = WidgetAgenda.dayEvents(agenda.events, day: now, calendar: calendar)
        let shown = Array(today.prefix(Self.maxRows))
        return VStack(alignment: .leading, spacing: 10) {
            DesktopWidgetHeader(title: strings.agenda, symbol: "calendar")
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(now, format: .dateTime.day())
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .foregroundStyle(DesktopPalette.today)
                VStack(alignment: .leading, spacing: 0) {
                    Text(now, format: .dateTime.weekday(.wide)).font(.system(size: 13, weight: .semibold))
                    Text(now, format: .dateTime.month(.wide)).font(.system(size: 12)).foregroundStyle(.secondary)
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
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(shown.enumerated()), id: \.offset) { _, event in
                        DesktopEventRow(event: event, now: now, strings: strings)
                    }
                    if today.count > shown.count {
                        Text(String(format: strings.moreFormat, today.count - shown.count))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            Text(tomorrowLine(agenda.events, now: now, strings: strings))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private func weekStrip(_ agenda: WidgetSnapshot.Agenda) -> some View {
        let days = WidgetAgenda.weekDays(containing: now, calendar: calendar)
        return HStack(spacing: 2) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                let isToday = calendar.isDate(day, inSameDayAs: now)
                let dayEvents = WidgetAgenda.dayEvents(agenda.events, day: day, calendar: calendar)
                VStack(spacing: 2) {
                    Text(day, format: .dateTime.weekday(.narrow))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(day, format: .dateTime.day())
                        .font(.system(size: 12, weight: isToday ? .bold : .regular))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 2)
                        .background(isToday ? DesktopPalette.today : Color.clear, in: RoundedRectangle(cornerRadius: 7))
                        .foregroundStyle(isToday ? Color.white : Color.primary)
                    EventDots(events: dayEvents)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

/// Up to three dots in the colours of a day's calendars.
private struct EventDots: View {
    let events: [WidgetSnapshot.AgendaEvent]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(events.prefix(3).enumerated()), id: \.offset) { _, event in
                Circle().fill(DesktopWidgetFormat.color(event)).frame(width: 4, height: 4)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Month

/// A whole month to browse: arrows to move a month, Today to come back, a
/// click on a day to list its events underneath.
struct DesktopMonthCard: View {
    @ObservedObject var model: DesktopMonthModel
    let now: Date
    let strings: DesktopWidgetsFeatureStrings
    let actions: DesktopWidgetActions

    private var calendar: Calendar { .current }

    var body: some View {
        if model.accessGranted == false {
            DesktopCalendarPlaceholder(title: strings.monthCalendar, text: strings.noCalendarAccess)
        } else {
            content
        }
    }

    private var content: some View {
        let days = WidgetAgenda.monthGrid(containing: model.month, calendar: calendar)
        let selectedEvents = WidgetAgenda.dayEvents(model.events, day: model.selected, calendar: calendar)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(model.month, format: .dateTime.month(.wide).year())
                    .font(.system(size: 17, weight: .bold))
                    .lineLimit(1)
                Spacer(minLength: 4)
                navButton("chevron.left") { actions.showMonth(-1) }
                Button(strings.today) { actions.showToday() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.08), in: Capsule())
                navButton("chevron.right") { actions.showMonth(1) }
            }
            weekdayHeader
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    dayCell(day)
                }
            }
            Divider().opacity(0.5)
            Text(model.selected, format: .dateTime.weekday(.wide).day().month(.wide))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(calendar.isDate(model.selected, inSameDayAs: now) ? DesktopPalette.today : .primary)
            if selectedEvents.isEmpty {
                Text(strings.noEventsOnDay)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(selectedEvents.enumerated()), id: \.offset) { _, event in
                            DesktopEventRow(event: event, now: now, strings: strings)
                        }
                    }
                }
            }
        }
    }

    private func navButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .frame(width: 22, height: 22)
                .background(Color.primary.opacity(0.08), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private var weekdayHeader: some View {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        let ordered = Array(symbols[first...] + symbols[..<first])
        return HStack(spacing: 2) {
            ForEach(Array(ordered.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let inMonth = calendar.isDate(day, equalTo: model.month, toGranularity: .month)
        let isToday = calendar.isDate(day, inSameDayAs: now)
        let isSelected = calendar.isDate(day, inSameDayAs: model.selected)
        let events = WidgetAgenda.dayEvents(model.events, day: day, calendar: calendar)
        return Button { actions.select(day) } label: {
            VStack(spacing: 2) {
                Text(day, format: .dateTime.day())
                    .font(.system(size: 13, weight: isToday || isSelected ? .bold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(isToday ? Color.white : (inMonth ? Color.primary : Color.secondary.opacity(0.6)))
                    .frame(width: 26, height: 26)
                    .background {
                        if isToday {
                            Circle().fill(DesktopPalette.today)
                        } else if isSelected {
                            Circle().fill(DesktopPalette.cpu.opacity(0.22))
                        }
                    }
                    .overlay {
                        if isSelected && isToday {
                            Circle().strokeBorder(Color.white.opacity(0.8), lineWidth: 1.5)
                        }
                    }
                EventDots(events: events)
            }
            .frame(maxWidth: .infinity, minHeight: 34)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - World clock

/// Up to four cities as analogue clocks, each with its hour difference and
/// whether it is already tomorrow or still yesterday there.
struct DesktopWorldClockCard: View {
    let now: Date
    let strings: DesktopWidgetsFeatureStrings

    var body: some View {
        let zones = DesktopWorldClock.zones(from: UserDefaults.standard.stringArray(forKey: DefaultsKey.desktopWidgetClocks))
        VStack(alignment: .leading, spacing: 8) {
            DesktopWidgetHeader(title: strings.worldClock, symbol: "globe")
            HStack(spacing: 6) {
                ForEach(zones, id: \.identifier) { zone in
                    clock(zone)
                }
            }
        }
    }

    private func clock(_ zone: TimeZone) -> some View {
        var calendar = Calendar.current
        calendar.timeZone = zone
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let night = hour < 6 || hour >= 19
        let dayShift = DesktopWorldClock.dayShift(at: now, in: zone)
        let offset = DesktopWorldClock.offsetText(at: now, in: zone)
        return VStack(spacing: 4) {
            AnalogClock(hour: hour, minute: minute, night: night)
                .frame(width: 64, height: 64)
            Text(DesktopWorldClock.cityName(zone))
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(dayShift > 0 ? "\(strings.tomorrowLabel) \(offset)"
                 : dayShift < 0 ? "\(strings.yesterdayLabel) \(offset)" : (offset.isEmpty ? strings.today : "\(strings.today) \(offset)"))
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

/// A clock face: light by day, dark by night, hour and minute hands.
private struct AnalogClock: View {
    let hour: Int
    let minute: Int
    let night: Bool

    var body: some View {
        let face = night ? Color(white: 0.12) : Color.white
        let ink = night ? Color.white : Color.black
        ZStack {
            Circle().fill(face)
            ForEach(0..<12, id: \.self) { mark in
                Capsule()
                    .fill(ink.opacity(mark % 3 == 0 ? 0.8 : 0.35))
                    .frame(width: mark % 3 == 0 ? 2 : 1.2, height: mark % 3 == 0 ? 6 : 4)
                    .offset(y: -25)
                    .rotationEffect(.degrees(Double(mark) * 30))
            }
            hand(length: 16, width: 3, angle: (Double(hour % 12) + Double(minute) / 60) * 30, color: ink)
            hand(length: 23, width: 2, angle: Double(minute) * 6, color: ink)
            Circle().fill(DesktopPalette.upload).frame(width: 5, height: 5)
        }
        .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
    }

    private func hand(length: CGFloat, width: CGFloat, angle: Double, color: Color) -> some View {
        Capsule()
            .fill(color)
            .frame(width: width, height: length)
            .offset(y: -length / 2)
            .rotationEffect(.degrees(angle))
    }
}

// MARK: - Accessories

/// The batteries of the Mac's accessories as rings with their icon, like the
/// system's own Batteries widget: up to four, the empty slots greyed.
struct DesktopAccessoriesCard: View {
    let power: WidgetSnapshot.Power?
    let strings: DesktopWidgetsFeatureStrings

    var body: some View {
        let devices = Array((power?.peripherals ?? []).prefix(4))
        VStack(spacing: 6) {
            DesktopWidgetHeader(title: strings.accessories, symbol: "keyboard")
            if devices.isEmpty {
                Spacer(minLength: 0)
                Text(strings.noAccessories)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer(minLength: 0)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(0..<4, id: \.self) { index in
                        if index < devices.count {
                            device(devices[index])
                        } else {
                            DesktopRing(fraction: 0, color: .clear) { EmptyView() }
                                .frame(width: 50, height: 50)
                        }
                    }
                }
            }
        }
    }

    private func device(_ device: WidgetSnapshot.Peripheral) -> some View {
        DesktopRing(fraction: Double(device.percent) / 100, color: DesktopPalette.battery(device.percent), lineWidth: 5) {
            Image(systemName: Self.symbol(device.kind))
                .font(.system(size: 15, weight: .medium))
        }
        .frame(width: 50, height: 50)
        .help("\(device.name) \(device.percent)%")
    }

    static func symbol(_ kind: String) -> String {
        switch kind {
        case "keyboard": return "keyboard"
        case "mouse": return "magicmouse"
        case "trackpad": return "rectangle.and.hand.point.up.left"
        case "audio": return "headphones"
        default: return "battery.75percent"
        }
    }
}

// MARK: - Weather

private func conditionName(_ condition: WeatherCondition, strings: DesktopWidgetsFeatureStrings) -> String {
    switch condition {
    case .clear: return strings.condClear
    case .partlyCloudy: return strings.condPartlyCloudy
    case .cloudy: return strings.condCloudy
    case .fog: return strings.condFog
    case .drizzle: return strings.condDrizzle
    case .rain: return strings.condRain
    case .snow: return strings.condSnow
    case .showers: return strings.condShowers
    case .thunderstorm: return strings.condThunderstorm
    }
}

/// The first city large, with its next hours, like the system's Weather
/// widget; the others below it, one row each.
struct DesktopWeatherCard: View {
    let strings: DesktopWidgetsFeatureStrings
    @ObservedObject private var weather = DesktopWeatherService.shared

    var body: some View {
        let cities = weather.cities
        VStack(alignment: .leading, spacing: 10) {
            DesktopWidgetHeader(title: strings.weather, symbol: "cloud.sun")
            if let first = cities.first, let report = weather.reports[first.id] {
                lead(first, report)
                if cities.count > 1 {
                    Divider().opacity(0.5)
                    VStack(spacing: 8) {
                        ForEach(cities.dropFirst()) { city in
                            row(city, weather.reports[city.id])
                        }
                    }
                }
                Spacer(minLength: 0)
                Text(report.fetchedAt, style: .time)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                Spacer(minLength: 0)
                Text(cities.isEmpty ? strings.addCity : strings.noForecast)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
    }

    private func lead(_ city: WeatherCity, _ report: WeatherReport) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(city.name)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    Text(DesktopWeather.degrees(report.temperature))
                        .font(.system(size: 46, weight: .light, design: .rounded))
                        .monospacedDigit()
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: report.condition.symbol(isDay: report.isDay))
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 26))
                    Text(conditionName(report.condition, strings: strings))
                        .font(.system(size: 12, weight: .semibold))
                    if let high = report.high, let low = report.low {
                        Text("↑\(DesktopWeather.degrees(high))  ↓\(DesktopWeather.degrees(low))")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            HStack(spacing: 0) {
                ForEach(Array(report.hours.enumerated()), id: \.offset) { _, hour in
                    VStack(spacing: 5) {
                        Text(String(format: "%02d", hour.hour))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Image(systemName: hour.condition.symbol(isDay: hour.isDay))
                            .symbolRenderingMode(.multicolor)
                            .font(.system(size: 16))
                            .frame(height: 20)
                        Text(DesktopWeather.degrees(hour.temperature))
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func row(_ city: WeatherCity, _ report: WeatherReport?) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                Text(city.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Text(report.map { conditionName($0.condition, strings: strings) } ?? strings.noForecast)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if let report {
                Image(systemName: report.condition.symbol(isDay: report.isDay))
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 18))
                if let high = report.high, let low = report.low {
                    Text("↑\(DesktopWeather.degrees(high)) ↓\(DesktopWeather.degrees(low))")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Text(DesktopWeather.degrees(report.temperature))
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .frame(width: 46, alignment: .trailing)
            }
        }
    }
}
