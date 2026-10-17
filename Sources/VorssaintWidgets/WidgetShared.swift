// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI
import WidgetKit

/// One drawing of a widget: the snapshot the app wrote, as of `date`.
struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
    /// False when the App Group folder cannot be reached from the sandbox,
    /// which the placeholder tells apart from "the app has not written yet".
    let containerReachable: Bool
}

/// Reads the app's snapshot for every widget. A widget whose picture changes
/// at known moments (an event starting, Keep Awake ending) names them in
/// `moments` and gets an entry at each, so "now" and "past" move without the
/// app running.
struct SnapshotProvider: TimelineProvider {
    var moments: ((WidgetSnapshot, Date) -> [Date])?

    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: Date(), snapshot: WidgetSample.snapshot(at: Date()), containerReachable: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        let now = Date()
        // The gallery shows made-up numbers so a widget can be judged before it is added.
        completion(context.isPreview
                   ? SnapshotEntry(date: now, snapshot: WidgetSample.snapshot(at: now), containerReachable: true)
                   : load(at: now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let now = Date()
        let first = load(at: now)
        var entries = [first]
        if let moments, let snapshot = first.snapshot {
            for moment in Set(moments(snapshot, now).filter { $0 > now }).sorted() {
                entries.append(SnapshotEntry(date: moment, snapshot: snapshot,
                                             containerReachable: first.containerReachable))
            }
        }
        // The app asks for a reload whenever it writes; this is the fallback
        // for when it is not running.
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(15 * 60))))
    }

    private func load(at date: Date) -> SnapshotEntry {
        let folder = WidgetAppGroup.snapshotFolder
        return SnapshotEntry(date: date, snapshot: folder.flatMap { WidgetSnapshotStore.read(from: $0) },
                             containerReachable: folder != nil)
    }
}

/// What a widget says when it has nothing to draw.
struct WidgetPlaceholder: View {
    let entry: SnapshotEntry
    var detail: LocalizedStringKey?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Vorssaint")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Group {
                if entry.snapshot == nil {
                    Text("No data yet")
                } else {
                    Text("Nothing to show")
                }
            }
            .font(.headline)
            Group {
                if let detail {
                    Text(detail)
                } else if entry.containerReachable {
                    Text("Open Vorssaint")
                } else {
                    Text("App Group unavailable")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// The small dot and clock time every widget carries: when the app last
/// wrote, greyed out once that is too old to trust.
struct WidgetStamp: View {
    let entry: SnapshotEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            HStack(spacing: 4) {
                Circle()
                    .fill(snapshot.isStale(at: entry.date) ? Color.secondary : Color.green)
                    .frame(width: 6, height: 6)
                Text(snapshot.generatedAt, style: .time)
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
        }
    }
}

struct WidgetHeader: View {
    let title: LocalizedStringKey
    let entry: SnapshotEntry

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            WidgetStamp(entry: entry)
        }
    }
}

enum WidgetFormat {
    static func bytes(_ count: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(min(count, UInt64(Int64.max))), countStyle: .file)
    }

    static func rate(_ bytesPerSecond: Double) -> String {
        bytes(UInt64(max(0, bytesPerSecond.isFinite ? bytesPerSecond : 0))) + "/s"
    }

    static func color(_ event: WidgetSnapshot.AgendaEvent) -> Color {
        Color(red: event.red, green: event.green, blue: event.blue)
    }
}
