// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Raw readings the app already holds, copied out of `SystemSnapshot`,
/// `PowerReading`, `KeepAwakeManager`, `AgentUsageSnapshot`, `NotchPlayback`
/// and the clipboard history. Plain values so the builder stays testable
/// without the services that produce them.
struct WidgetSnapshotInputs {
    struct LimitWindow {
        var provider: String
        var kind: String
        var minutes: Int?
        var usedPercent: Double
        var resetsAt: Date?
    }

    struct Peripheral {
        var name: String
        var percent: Int
        /// How long ago the reading was taken; the monitor keeps the last one
        /// after it stops sampling, so an old value must not pass as current.
        var secondsSinceRead: TimeInterval
        var kind: String = "device"
    }

    struct Playback {
        var title: String
        var artist: String
        var isPlaying: Bool
        var elapsed: TimeInterval
        var duration: TimeInterval
        var sampledAt: Date
    }

    /// The fields of `PowerReading` a widget shows.
    struct Power {
        var hasBattery = false
        var chargePercent: Int?
        var isCharging = false
        var externalConnected = false
        var timeRemainingSeconds: TimeInterval?
    }

    struct AgendaEvent {
        var title: String
        var calendarName: String
        var location: String
        var start: Date
        var end: Date
        var allDay: Bool
        var red: Double
        var green: Double
        var blue: Double
    }

    struct ClipboardEntry {
        var kind: WidgetSnapshot.ClipboardItem.Kind
        var text: String
        var filePaths: [String] = []
        var copiedAt: Date
    }

    // System, fractions 0...1 as `SystemSnapshot` keeps them
    var cpuUsage: Double?
    var cpuHistory: [Double] = []
    var gpuUsage: Double?
    var memoryUsed: UInt64?
    var memoryTotal: UInt64?
    var memoryPressure: String?
    var cpuTemperature: Double?
    var netDownBytesPerSec: Double?
    var netUpBytesPerSec: Double?
    var diskFreeBytes: UInt64?
    var diskTotalBytes: UInt64?
    /// Fractions 0...1 (memory, GPU) and bytes per second (network), oldest first.
    var memoryHistory: [Double] = []
    var gpuHistory: [Double] = []
    var netDownHistory: [Double] = []
    var netUpHistory: [Double] = []

    // Power; nil when the Mac reported nothing (a desktop with no SMC power keys)
    var power: Power?
    var peripherals: [Peripheral] = []

    var keepAwakeActive = false
    var keepAwakeEnd: Date?

    var agentWindows: [LimitWindow] = []
    var agentTodayTokens: Int?
    var agentLiveSessions = 0
    var agentsLoaded = false

    var playback: Playback?

    /// nil when the calendar was never read (no snapshot section at all).
    var agendaAccessGranted: Bool?
    var agendaEvents: [AgendaEvent] = []
    /// The person's choice; on by default, off keeps titles and places off the desk.
    var showsEventTitles = true

    var clipboard: [ClipboardEntry] = []
    /// The person's choice; off by default because history can hold private text.
    var showsClipboard = false
}

enum WidgetSnapshotBuilder {
    /// The longest line a card draws. The desktop cards sample every few
    /// seconds (a few minutes of history); the widget extension once a minute.
    static let historyPoints = 60
    /// A week of events, for the strip of days; only today's and tomorrow's
    /// carry a title or a place.
    static let maxAgendaEvents = 40
    static let maxEventTitleCharacters = 80
    static let maxEventLocationCharacters = 60
    static let maxPeripherals = 3
    /// Older than this, a battery reading is left out rather than shown.
    static let maxPeripheralAge: TimeInterval = 10 * 60
    static let maxAgentWindows = 3
    static let maxClipboardItems = 3
    static let maxPreviewCharacters = 60
    static let maxTrackCharacters = 80

    static func build(_ inputs: WidgetSnapshotInputs, now: Date,
                      calendar: Calendar = .current) -> WidgetSnapshot {
        WidgetSnapshot(
            generatedAt: now,
            system: system(inputs),
            power: power(inputs),
            keepAwake: WidgetSnapshot.KeepAwake(
                isActive: inputs.keepAwakeActive,
                endsAt: inputs.keepAwakeActive ? inputs.keepAwakeEnd : nil),
            agents: agents(inputs, now: now),
            agenda: agenda(inputs, now: now, calendar: calendar),
            nowPlaying: nowPlaying(inputs.playback),
            clipboard: inputs.showsClipboard ? clipboard(inputs.clipboard) : [])
    }

    // MARK: - Sections

    private static func system(_ inputs: WidgetSnapshotInputs) -> WidgetSnapshot.System? {
        var memory: Int?
        if let used = inputs.memoryUsed, let total = inputs.memoryTotal, total > 0 {
            memory = percent(Double(used) / Double(total))
        }
        let section = WidgetSnapshot.System(
            cpuPercent: inputs.cpuUsage.flatMap(percent),
            cpuHistory: downsample(inputs.cpuHistory, to: historyPoints).compactMap(percent),
            gpuPercent: inputs.gpuUsage.flatMap(percent),
            memoryPercent: memory,
            memoryPressure: inputs.memoryPressure,
            cpuTemperatureCelsius: inputs.cpuTemperature.flatMap(rounded),
            netDownBytesPerSec: inputs.netDownBytesPerSec.flatMap(nonNegative),
            netUpBytesPerSec: inputs.netUpBytesPerSec.flatMap(nonNegative),
            diskFreeBytes: inputs.diskFreeBytes,
            diskTotalBytes: inputs.diskTotalBytes,
            memoryHistory: downsample(inputs.memoryHistory, to: historyPoints).compactMap(percent),
            gpuHistory: downsample(inputs.gpuHistory, to: historyPoints).compactMap(percent),
            netDownHistory: downsample(inputs.netDownHistory, to: historyPoints).map { max(0, $0) },
            netUpHistory: downsample(inputs.netUpHistory, to: historyPoints).map { max(0, $0) })
        return section == WidgetSnapshot.System() ? nil : section
    }

    private static func power(_ inputs: WidgetSnapshotInputs) -> WidgetSnapshot.Power? {
        // Lowest first: the device about to die is the one worth a glance.
        let peripherals = Array(inputs.peripherals.compactMap { device -> WidgetSnapshot.Peripheral? in
            let name = device.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, device.secondsSinceRead.isFinite,
                  device.secondsSinceRead <= maxPeripheralAge else { return nil }
            return WidgetSnapshot.Peripheral(name: name, percent: min(100, max(0, device.percent)),
                                             kind: device.kind)
        }.sorted { ($0.percent, $0.name) < ($1.percent, $1.name) }.prefix(maxPeripherals))
        let reading = inputs.power
        guard reading != nil || !peripherals.isEmpty else { return nil }
        return WidgetSnapshot.Power(
            hasBattery: reading?.hasBattery ?? false,
            chargePercent: reading?.chargePercent.map { min(100, max(0, $0)) },
            isCharging: reading?.isCharging ?? false,
            externalConnected: reading?.externalConnected ?? false,
            timeRemainingSeconds: reading?.timeRemainingSeconds.flatMap(rounded).flatMap { $0 > 0 ? $0 : nil },
            peripherals: peripherals)
    }

    private static func agents(_ inputs: WidgetSnapshotInputs, now: Date) -> WidgetSnapshot.Agents? {
        guard inputs.agentsLoaded else { return nil }
        // A window whose renewal has passed says nothing about the new one, so
        // it is left out rather than shown as spent.
        let windows = inputs.agentWindows.compactMap { window -> WidgetSnapshot.LimitWindow? in
            guard let used = rounded(window.usedPercent) else { return nil }
            if let renewal = window.resetsAt, renewal <= now { return nil }
            return WidgetSnapshot.LimitWindow(provider: window.provider, kind: window.kind,
                                              minutes: window.minutes, usedPercent: min(100, max(0, used)),
                                              resetsAt: window.resetsAt)
        }.prefix(maxAgentWindows)
        return WidgetSnapshot.Agents(windows: Array(windows),
                                     todayTokens: inputs.agentTodayTokens.map { max(0, $0) },
                                     liveSessions: max(0, inputs.agentLiveSessions))
    }

    private static func agenda(_ inputs: WidgetSnapshotInputs, now: Date,
                               calendar: Calendar) -> WidgetSnapshot.Agenda? {
        guard let granted = inputs.agendaAccessGranted else { return nil }
        guard granted else { return WidgetSnapshot.Agenda(accessGranted: false) }
        // Text leaves the app only for the two days a widget lists; the rest
        // of the week is only there to mark which days are busy.
        let textUntil = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: now))
            ?? now.addingTimeInterval(2 * 86_400)
        let events = inputs.agendaEvents
            .filter { $0.end >= $0.start && $0.start.timeIntervalSince1970.isFinite }
            .prefix(maxAgendaEvents)
            .map { event -> WidgetSnapshot.AgendaEvent in
                WidgetSnapshot.AgendaEvent(
                    title: inputs.showsEventTitles && event.start < textUntil
                        ? truncated(collapsed(event.title), to: maxEventTitleCharacters) : "",
                    calendarName: truncated(collapsed(event.calendarName), to: maxEventTitleCharacters),
                    location: inputs.showsEventTitles && event.start < textUntil
                        ? truncated(collapsed(event.location), to: maxEventLocationCharacters) : "",
                    start: event.start, end: event.end, allDay: event.allDay,
                    red: unit(event.red), green: unit(event.green), blue: unit(event.blue))
            }
        return WidgetSnapshot.Agenda(accessGranted: true, events: Array(events))
    }

    private static func unit(_ value: Double) -> Double {
        value.isFinite ? min(1, max(0, value)) : 0
    }

    private static func nowPlaying(_ playback: WidgetSnapshotInputs.Playback?) -> WidgetSnapshot.NowPlaying? {
        guard let playback else { return nil }
        let title = truncated(collapsed(playback.title), to: maxTrackCharacters)
        guard !title.isEmpty else { return nil }
        let duration = playback.duration.isFinite ? max(0, playback.duration) : 0
        let elapsed = playback.elapsed.isFinite ? min(max(0, playback.elapsed), duration > 0 ? duration : .greatestFiniteMagnitude) : 0
        return WidgetSnapshot.NowPlaying(
            title: title,
            artist: truncated(collapsed(playback.artist), to: maxTrackCharacters),
            isPlaying: playback.isPlaying,
            elapsed: elapsed,
            duration: duration,
            sampledAt: playback.sampledAt)
    }

    private static func clipboard(_ entries: [WidgetSnapshotInputs.ClipboardEntry]) -> [WidgetSnapshot.ClipboardItem] {
        let items = entries.compactMap { entry -> WidgetSnapshot.ClipboardItem? in
            switch entry.kind {
            case .text:
                let preview = truncated(collapsed(entry.text), to: maxPreviewCharacters)
                guard !preview.isEmpty else { return nil }
                return .init(kind: .text, preview: preview, copiedAt: entry.copiedAt)
            case .image:
                return .init(kind: .image, preview: "", copiedAt: entry.copiedAt)
            case .files:
                guard let first = entry.filePaths.first else { return nil }
                let name = truncated((first as NSString).lastPathComponent, to: maxPreviewCharacters)
                return .init(kind: .files, preview: name, copiedAt: entry.copiedAt)
            }
        }
        return Array(items.sorted { $0.copiedAt > $1.copiedAt }.prefix(maxClipboardItems))
    }

    // MARK: - Values

    /// 0...1 fraction to a whole percent; nil for readings that are not numbers.
    static func percent(_ fraction: Double) -> Int? {
        guard fraction.isFinite else { return nil }
        return Int((min(1, max(0, fraction)) * 100).rounded())
    }

    private static func rounded(_ value: Double) -> Int? {
        guard value.isFinite, abs(value) < Double(Int.max) else { return nil }
        return Int(value.rounded())
    }

    private static func nonNegative(_ value: Double) -> Double? {
        value.isFinite ? max(0, value) : nil
    }

    /// Averages consecutive buckets so the newest reading stays the last point.
    static func downsample(_ values: [Double], to count: Int) -> [Double] {
        let finite = values.filter(\.isFinite)
        guard count > 0, finite.count > count else { return finite }
        var result: [Double] = []
        result.reserveCapacity(count)
        for bucket in 0..<count {
            let lower = bucket * finite.count / count
            let upper = (bucket + 1) * finite.count / count
            let slice = finite[lower..<upper]
            result.append(slice.reduce(0, +) / Double(slice.count))
        }
        return result
    }

    /// Line breaks and runs of spaces become one space, so a copied paragraph
    /// reads as a single line in a widget row.
    static func collapsed(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).joined(separator: " ")
    }

    static func truncated(_ text: String, to limit: Int) -> String {
        guard text.count > limit, limit > 1 else { return text }
        return String(text.prefix(limit - 1)).trimmingCharacters(in: .whitespaces) + "…"
    }
}
