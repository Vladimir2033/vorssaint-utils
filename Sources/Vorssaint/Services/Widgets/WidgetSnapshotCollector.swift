// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import EventKit
import Foundation

/// Gathers what the widgets show from the services the app already runs, as
/// one `WidgetSnapshot`. The desktop cards read it in the app; the optional
/// macOS widget extension reads the same snapshot from a file.
///
/// Agent usage comes from the service the island's AI section runs: nothing
/// here starts that reading of the agents' logs. The calendar is read, never
/// requested: without permission the snapshot says so.
@MainActor
final class WidgetSnapshotCollector {
    private let calendarReader = NotchCalendarReader()
    /// One point per recorded sample; the lines are what the app has seen.
    private var cpuHistory: [Double] = []
    private var memoryHistory: [Double] = []
    private var gpuHistory: [Double] = []
    private var netDownHistory: [Double] = []
    private var netUpHistory: [Double] = []
    private var agenda: (accessGranted: Bool, events: [WidgetSnapshotInputs.AgendaEvent])?

    /// `recordsHistory` adds a CPU point (about once a minute);
    /// `readsAgenda` reads the calendar again instead of reusing the last read.
    func collect(recordsHistory: Bool, readsAgenda: Bool) async -> WidgetSnapshot {
        var inputs = systemInputs(recordsHistory: recordsHistory)
        inputs.keepAwakeActive = KeepAwakeManager.shared.isActive
        inputs.keepAwakeEnd = KeepAwakeManager.shared.endDate
        let agents = agentInputs()
        inputs.agentsLoaded = agents.loaded
        inputs.agentWindows = agents.windows
        inputs.agentTodayTokens = agents.loaded ? agents.todayTokens : nil
        inputs.agentLiveSessions = agents.liveSessions
        if readsAgenda || agenda == nil { agenda = await readAgenda() }
        inputs.showsEventTitles = UserDefaults.standard.bool(forKey: DefaultsKey.widgetCalendarShowsTitles)
        inputs.agendaAccessGranted = agenda?.accessGranted
        inputs.agendaEvents = agenda?.events ?? []
        return WidgetSnapshotBuilder.build(inputs, now: Date())
    }

    private func systemInputs(recordsHistory: Bool) -> WidgetSnapshotInputs {
        let reading = SystemMonitor.shared.snapshot
        if recordsHistory {
            func record(_ value: Double?, into history: inout [Double]) {
                guard let value, value.isFinite else { return }
                history.append(value)
                if history.count > WidgetSnapshotBuilder.historyPoints {
                    history.removeFirst(history.count - WidgetSnapshotBuilder.historyPoints)
                }
            }
            var memory: Double?
            if let used = reading.memoryUsed, let total = reading.memoryTotal, total > 0 {
                memory = Double(used) / Double(total)
            }
            record(reading.cpuUsage, into: &cpuHistory)
            record(memory, into: &memoryHistory)
            record(reading.gpuUsage, into: &gpuHistory)
            record(reading.netDownBytesPerSec, into: &netDownHistory)
            record(reading.netUpBytesPerSec, into: &netUpHistory)
        }
        var inputs = WidgetSnapshotInputs()
        inputs.cpuUsage = reading.cpuUsage
        inputs.cpuHistory = cpuHistory
        inputs.memoryHistory = memoryHistory
        inputs.gpuHistory = gpuHistory
        inputs.netDownHistory = netDownHistory
        inputs.netUpHistory = netUpHistory
        inputs.gpuUsage = reading.gpuUsage
        inputs.memoryUsed = reading.memoryUsed
        inputs.memoryTotal = reading.memoryTotal
        inputs.memoryPressure = Self.pressureName(reading.memoryPressure)
        inputs.cpuTemperature = reading.cpuTemperature
        inputs.netDownBytesPerSec = reading.netDownBytesPerSec
        inputs.netUpBytesPerSec = reading.netUpBytesPerSec
        let disk = reading.disk?.devices.first(where: \.isInternal) ?? reading.disk?.devices.first
        inputs.diskFreeBytes = disk?.freeBytes
        inputs.diskTotalBytes = disk?.totalBytes
        inputs.power = reading.power.map {
            WidgetSnapshotInputs.Power(hasBattery: $0.hasBattery, chargePercent: $0.chargePercent,
                                       isCharging: $0.isCharging, externalConnected: $0.externalConnected,
                                       timeRemainingSeconds: $0.timeRemainingSeconds)
        }
        let uptime = ProcessInfo.processInfo.systemUptime
        inputs.peripherals = reading.peripheralBatteries.compactMap { device in
            guard let observed = reading.peripheralBatterySample.observedAt[device.id] else { return nil }
            return WidgetSnapshotInputs.Peripheral(name: device.name, percent: device.percent,
                                                   secondsSinceRead: uptime - observed,
                                                   kind: device.kind.rawValue)
        }
        return inputs
    }

    private static func pressureName(_ pressure: MemoryPressure) -> String? {
        switch pressure {
        case .normal: return "normal"
        case .warning: return "warning"
        case .critical: return "critical"
        case .unknown: return nil
        }
    }

    /// The limits the agents report for everything they cover (no single
    /// model), the day's tokens and the sessions under way. Nothing until the
    /// island's AI section has read the logs.
    private func agentInputs() -> (loaded: Bool, windows: [WidgetSnapshotInputs.LimitWindow],
                                   todayTokens: Int, liveSessions: Int) {
        let usage = AgentUsageService.shared.snapshot
        guard usage.loaded else { return (false, [], 0, 0) }
        func rank(_ window: AgentLimitWindow) -> Int {
            switch window.kind {
            case .session: return 0
            case .weekly: return 1
            case .other: return 2
            }
        }
        let windows = AgentProvider.allCases.flatMap { provider -> [WidgetSnapshotInputs.LimitWindow] in
            (usage.limits[provider]?.windows ?? [])
                .filter { $0.scope == nil }
                .sorted { rank($0) < rank($1) }
                .prefix(2)
                .map {
                    WidgetSnapshotInputs.LimitWindow(provider: provider.displayName, kind: $0.kind.rawValue,
                                                     minutes: $0.minutes, usedPercent: $0.usedPercent,
                                                     resetsAt: $0.resetsAt)
                }
        }
        return (true, windows, usage.usage(.today).total.tokens.total, usage.live.count)
    }

    /// Every event in `interval`, for the month card, with titles and places
    /// unless the person keeps them off the desk. Nothing here leaves the app,
    /// so unlike the snapshot there is no two-day limit on the text.
    func events(in interval: DateInterval) async -> (accessGranted: Bool, events: [WidgetSnapshot.AgendaEvent]) {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return (false, []) }
        let showsTitles = UserDefaults.standard.bool(forKey: DefaultsKey.widgetCalendarShowsTitles)
        let events = await calendarReader.read(interval: interval,
                                               excluded: NotchCalendarSupport.excludedCalendars())
        return (true, NotchCalendarSupport.ordered(events).map {
            WidgetSnapshot.AgendaEvent(
                title: showsTitles ? $0.title : "", calendarName: $0.calendar,
                location: showsTitles ? $0.location : "",
                start: $0.start, end: $0.end, allDay: $0.allDay,
                red: $0.color.red, green: $0.color.green, blue: $0.color.blue)
        })
    }

    /// A week from today, from the calendars the person left on in the
    /// island's list. Never asks for permission.
    private func readAgenda() async -> (accessGranted: Bool, events: [WidgetSnapshotInputs.AgendaEvent]) {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return (false, []) }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 7, to: start) else { return (true, []) }
        let events = await calendarReader.read(interval: DateInterval(start: start, end: end),
                                               excluded: NotchCalendarSupport.excludedCalendars())
        let mapped = NotchCalendarSupport.ordered(events).map {
            WidgetSnapshotInputs.AgendaEvent(
                title: $0.title, calendarName: $0.calendar, location: $0.location,
                start: $0.start, end: $0.end, allDay: $0.allDay,
                red: $0.color.red, green: $0.color.green, blue: $0.color.blue)
        }
        return (true, mapped)
    }
}
