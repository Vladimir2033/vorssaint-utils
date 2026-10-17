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
    /// One CPU point per recorded sample; the line is what the app has seen.
    private var cpuHistory: [Double] = []
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
        if recordsHistory, let cpu = reading.cpuUsage {
            cpuHistory.append(cpu)
            if cpuHistory.count > WidgetSnapshotBuilder.historyPoints {
                cpuHistory.removeFirst(cpuHistory.count - WidgetSnapshotBuilder.historyPoints)
            }
        }
        var inputs = WidgetSnapshotInputs()
        inputs.cpuUsage = reading.cpuUsage
        inputs.cpuHistory = cpuHistory
        inputs.gpuUsage = reading.gpuUsage
        inputs.memoryUsed = reading.memoryUsed
        inputs.memoryTotal = reading.memoryTotal
        inputs.memoryPressure = Self.pressureName(reading.memoryPressure)
        inputs.cpuTemperature = reading.cpuTemperature
        inputs.netDownBytesPerSec = reading.netDownBytesPerSec
        inputs.netUpBytesPerSec = reading.netUpBytesPerSec
        let disk = reading.disk?.devices.first(where: \.isInternal) ?? reading.disk?.devices.first
        inputs.diskFreeBytes = disk?.freeBytes
        inputs.power = reading.power.map {
            WidgetSnapshotInputs.Power(hasBattery: $0.hasBattery, chargePercent: $0.chargePercent,
                                       isCharging: $0.isCharging, externalConnected: $0.externalConnected,
                                       timeRemainingSeconds: $0.timeRemainingSeconds)
        }
        let uptime = ProcessInfo.processInfo.systemUptime
        inputs.peripherals = reading.peripheralBatteries.compactMap { device in
            guard let observed = reading.peripheralBatterySample.observedAt[device.id] else { return nil }
            return WidgetSnapshotInputs.Peripheral(name: device.name, percent: device.percent,
                                                   secondsSinceRead: uptime - observed)
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
