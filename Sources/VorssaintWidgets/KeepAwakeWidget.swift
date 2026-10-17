// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI
import WidgetKit

struct KeepAwakeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "VorssaintKeepAwake",
                            provider: SnapshotProvider(moments: { snapshot, _ in
                                snapshot.keepAwake.endsAt.map { [$0] } ?? []
                            })) { entry in
            KeepAwakeWidgetView(entry: entry)
        }
        .configurationDisplayName("Keep Awake")
        .description("Whether your Mac is being kept awake, and until when.")
        .supportedFamilies([.systemSmall])
    }
}

struct KeepAwakeWidgetView: View {
    let entry: SnapshotEntry

    var body: some View {
        Group {
            if let keepAwake = entry.snapshot?.keepAwake {
                content(keepAwake)
            } else {
                WidgetPlaceholder(entry: entry)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func content(_ keepAwake: WidgetSnapshot.KeepAwake) -> some View {
        let on = keepAwake.isOn(at: entry.date)
        return VStack(alignment: .leading, spacing: 6) {
            WidgetHeader(title: "Keep Awake", entry: entry)
            Spacer(minLength: 0)
            Image(systemName: on ? "cup.and.saucer.fill" : "moon.zzz")
                .font(.system(size: 26))
                .foregroundStyle(on ? Color.accentColor : Color.secondary)
            if on {
                Text("On")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.green)
                if let end = keepAwake.endsAt {
                    HStack(spacing: 4) {
                        Text("until").font(.system(size: 13)).foregroundStyle(.secondary)
                        Text(end, style: .time).font(.system(size: 24, weight: .semibold))
                    }
                    Text(end, style: .relative)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("No end time")
                        .font(.system(size: 17, weight: .semibold))
                }
            } else {
                Text("Off")
                    .font(.system(size: 24, weight: .semibold))
                Text("The Mac sleeps as usual")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
