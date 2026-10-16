// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation
import WidgetKit

/// Keeps the widgets' snapshot current while the app runs.
///
/// Phase 0 of the desktop widgets: only Keep Awake goes in, which is enough
/// to prove on a real Mac that the app writes, the sandboxed extension reads
/// and the reload reaches the desk. The other readings join once that holds.
/// Builds without `--widgets` have no App Group and this does nothing.
final class WidgetSnapshotWriter {
    static let shared = WidgetSnapshotWriter()

    private var throttle = WidgetSnapshotThrottle()
    private var timer: Timer?

    func start() {
        guard timer == nil, WidgetAppGroup.snapshotFolder != nil else { return }
        write()
        let timer = Timer(timeInterval: WidgetSnapshotThrottle.minimumInterval, repeats: true) { [weak self] _ in
            self?.write()
        }
        // The panel's tracking loop would otherwise pause the timer while open.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func write() {
        guard let folder = WidgetAppGroup.snapshotFolder else { return }
        var inputs = WidgetSnapshotInputs()
        inputs.keepAwakeActive = KeepAwakeManager.shared.isActive
        inputs.keepAwakeEnd = KeepAwakeManager.shared.endDate
        let snapshot = WidgetSnapshotBuilder.build(inputs, now: Date())
        guard throttle.shouldWrite(snapshot, now: snapshot.generatedAt),
              WidgetSnapshotStore.write(snapshot, to: folder)
        else { return }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
