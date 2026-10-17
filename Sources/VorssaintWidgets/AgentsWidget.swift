// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI
import WidgetKit

struct AgentsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "VorssaintAgents", provider: SnapshotProvider()) { entry in
            AgentsWidgetView(entry: entry)
        }
        .configurationDisplayName("AI usage")
        .description("How much of your coding agents' allowances is spent, and today's tokens.")
        .supportedFamilies([.systemMedium])
    }
}

struct AgentsWidgetView: View {
    let entry: SnapshotEntry

    var body: some View {
        Group {
            if let agents = entry.snapshot?.agents {
                content(agents)
            } else if entry.snapshot != nil {
                WidgetPlaceholder(entry: entry, detail: "Turn on the AI section in the Dynamic Island")
            } else {
                WidgetPlaceholder(entry: entry)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func content(_ agents: WidgetSnapshot.Agents) -> some View {
        let renewal = agents.windows.compactMap(\.resetsAt).filter { $0 > entry.date }.min()
        return VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(title: "AI usage", entry: entry)
            if agents.windows.isEmpty {
                Spacer(minLength: 0)
                Text("No allowance reported")
                    .font(.system(size: 13, weight: .semibold))
                Text("Your agents have not written a limit yet")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(agents.windows.enumerated()), id: \.offset) { _, window in
                        row(window)
                    }
                }
            }
            Spacer(minLength: 0)
            HStack {
                if let tokens = agents.todayTokens {
                    Text("\(tokens.formatted(.number.notation(.compactName))) tokens today")
                }
                Spacer(minLength: 6)
                if let renewal {
                    HStack(spacing: 3) {
                        Text("renews")
                        Text(renewal, style: .time)
                    }
                } else if agents.liveSessions > 0 {
                    Text("\(agents.liveSessions) running")
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
    }

    private func row(_ window: WidgetSnapshot.LimitWindow) -> some View {
        HStack(spacing: 10) {
            Text(label(window))
                .font(.system(size: 12))
                .lineLimit(1)
                .frame(width: 104, alignment: .leading)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.12))
                GeometryReader { proxy in
                    Capsule()
                        .fill(tint(window.usedPercent))
                        .frame(width: proxy.size.width * CGFloat(window.usedPercent) / 100)
                }
            }
            .frame(height: 8)
            Text("\(window.usedPercent)%")
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .frame(width: 40, alignment: .trailing)
        }
    }

    /// The agent's name, then how long the allowance lasts.
    private func label(_ window: WidgetSnapshot.LimitWindow) -> String {
        let kind: String
        switch window.kind {
        case "session":
            kind = window.minutes == 300 ? String(localized: "5 h") : String(localized: "Session")
        case "weekly":
            kind = String(localized: "Week")
        default:
            kind = String(localized: "Limit")
        }
        return window.provider + " · " + kind
    }

    private func tint(_ percent: Int) -> Color {
        if percent >= 95 { return .red }
        if percent >= 80 { return .orange }
        return .accentColor
    }
}
