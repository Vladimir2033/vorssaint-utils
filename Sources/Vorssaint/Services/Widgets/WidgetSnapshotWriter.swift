// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import EventKit
import Foundation
import WidgetKit

/// Keeps the snapshot file the optional macOS widget extension reads current
/// (`build.sh --widgets`). Builds without the extension have no App Group and
/// this does nothing, so it never asks the system monitor to sample and never
/// touches EventKit. The desktop cards do not use it.
@MainActor
final class WidgetSnapshotWriter {
    static let shared = WidgetSnapshotWriter()

    private var throttle = WidgetSnapshotThrottle()
    private var timer: Timer?
    private var task: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private let collector = WidgetSnapshotCollector()

    func start() {
        guard timer == nil, WidgetAppGroup.snapshotFolder != nil else { return }
        SystemMonitor.shared.setWidgetsMonitoring(true, consumer: "extension")
        let timer = Timer(timeInterval: WidgetSnapshotThrottle.minimumInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.update(recordsHistory: true) }
        }
        // The panel's tracking loop would otherwise pause the timer while open.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        // A changed calendar, a new day, or a clock change should not wait for the minute.
        for name in [Notification.Name.EKEventStoreChanged, .NSSystemClockDidChange,
                     .NSSystemTimeZoneDidChange, .NSCalendarDayChanged] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) {
                [weak self] _ in
                Task { @MainActor in self?.update(recordsHistory: false) }
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
        SystemMonitor.shared.setWidgetsMonitoring(false, consumer: "extension")
    }

    private func update(recordsHistory: Bool) {
        guard let folder = WidgetAppGroup.snapshotFolder else { return }
        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            let snapshot = await self.collector.collect(recordsHistory: recordsHistory, readsAgenda: true)
            guard !Task.isCancelled else { return }
            guard self.throttle.shouldWrite(snapshot, now: snapshot.generatedAt),
                  WidgetSnapshotStore.write(snapshot, to: folder)
            else { return }
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
