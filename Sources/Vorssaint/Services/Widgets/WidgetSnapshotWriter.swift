// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import EventKit
import Foundation
import WidgetKit

/// Keeps the widgets' snapshot current while the app runs.
///
/// System readings, battery, Keep Awake, the calendar agenda and AI usage.
/// Agent usage is read from the service the island already runs; the widget
/// never starts that reading of the agents' logs by itself. Builds without `--widgets` have no App Group and this does nothing, so it
/// never asks the system monitor to sample and never touches EventKit.
final class WidgetSnapshotWriter {
    static let shared = WidgetSnapshotWriter()

    private var throttle = WidgetSnapshotThrottle()
    private var timer: Timer?
    private var task: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private let calendarReader = NotchCalendarReader()
    /// One CPU point per timer tick; the sparkline is what the app has seen.
    private var cpuHistory: [Double] = []

    func start() {
        guard timer == nil, WidgetAppGroup.snapshotFolder != nil else { return }
        SystemMonitor.shared.setWidgetsMonitoring(true)
        let timer = Timer(timeInterval: WidgetSnapshotThrottle.minimumInterval, repeats: true) { [weak self] _ in
            self?.update(recordsHistory: true)
        }
        // The panel's tracking loop would otherwise pause the timer while open.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        // A changed calendar, a new day, or a clock change should not wait for the minute.
        for name in [Notification.Name.EKEventStoreChanged, .NSSystemClockDidChange,
                     .NSSystemTimeZoneDidChange, .NSCalendarDayChanged] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) {
                [weak self] _ in self?.update(recordsHistory: false)
            })
        }
        update(recordsHistory: true)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        task?.cancel()
        task = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        SystemMonitor.shared.setWidgetsMonitoring(false)
    }

    private func update(recordsHistory: Bool) {
        guard let folder = WidgetAppGroup.snapshotFolder else { return }
        task?.cancel()
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            var inputs = self.systemInputs(recordsHistory: recordsHistory)
            inputs.keepAwakeActive = KeepAwakeManager.shared.isActive
            inputs.keepAwakeEnd = KeepAwakeManager.shared.endDate
            let agents = self.agentInputs()
            inputs.agentsLoaded = agents.loaded
            inputs.agentWindows = agents.windows
            inputs.agentTodayTokens = agents.loaded ? agents.todayTokens : nil
            inputs.agentLiveSessions = agents.liveSessions
            let agenda = await self.readAgenda()
            guard !Task.isCancelled else { return }
            inputs.showsEventTitles = UserDefaults.standard.bool(forKey: DefaultsKey.widgetCalendarShowsTitles)
            inputs.agendaAccessGranted = agenda.accessGranted
            inputs.agendaEvents = agenda.events
            let snapshot = WidgetSnapshotBuilder.build(inputs, now: Date())
            guard self.throttle.shouldWrite(snapshot, now: snapshot.generatedAt),
                  WidgetSnapshotStore.write(snapshot, to: folder)
            else { return }
            WidgetCenter.shared.reloadAllTimelines()
        }
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

    private static func pressureName(_ pressure: MemoryPressure) -> String? {
        switch pressure {
        case .normal: return "normal"
        case .warning: return "warning"
        case .critical: return "critical"
        case .unknown: return nil
        }
    }

    /// A week from today, from the calendars the person left on in the
    /// island's list. Never asks for permission: the widget says so when the
    /// app has none.
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
