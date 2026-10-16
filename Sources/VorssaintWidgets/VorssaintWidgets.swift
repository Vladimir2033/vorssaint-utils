// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI
import WidgetKit

/// Phase 0 probe: one small widget that says whether the extension can read
/// the snapshot the app writes. Each line answers one question on a real Mac:
/// does the gallery list it, is the group container reachable from the
/// sandbox, did the app write, and how old is what it wrote.
struct ProbeEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
    let containerReachable: Bool
}

struct ProbeProvider: TimelineProvider {
    func placeholder(in context: Context) -> ProbeEntry {
        ProbeEntry(date: Date(), snapshot: nil, containerReachable: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (ProbeEntry) -> Void) {
        completion(load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ProbeEntry>) -> Void) {
        // The app asks for a reload whenever it writes; this is only the
        // fallback for when it is not running.
        completion(Timeline(entries: [load()], policy: .after(Date().addingTimeInterval(15 * 60))))
    }

    private func load() -> ProbeEntry {
        let folder = WidgetAppGroup.snapshotFolder
        return ProbeEntry(date: Date(),
                          snapshot: folder.flatMap { WidgetSnapshotStore.read(from: $0) },
                          containerReachable: folder != nil)
    }
}

struct ProbeView: View {
    let entry: ProbeEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Vorssaint")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            if let snapshot = entry.snapshot {
                Text("Hello")
                    .font(.title2.weight(.bold))
                Text(snapshot.keepAwake.isActive ? "Keep Awake on" : "Keep Awake off")
                    .font(.caption)
                Text("Written \(snapshot.generatedAt, style: .time)")
                    .font(.caption2)
                    .foregroundStyle(snapshot.isStale(at: entry.date) ? .secondary : .primary)
            } else {
                Text("No snapshot")
                    .font(.headline)
                Text(entry.containerReachable ? "Open Vorssaint" : "App Group unavailable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct ProbeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "VorssaintProbe", provider: ProbeProvider()) { entry in
            ProbeView(entry: entry)
        }
        .configurationDisplayName("Vorssaint probe")
        .description("Shows whether the widget can read what Vorssaint writes.")
        .supportedFamilies([.systemSmall])
    }
}

@main
struct VorssaintWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ProbeWidget()
    }
}
