// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI
import WidgetKit

struct BatteryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "VorssaintBattery", provider: SnapshotProvider()) { entry in
            BatteryWidgetView(entry: entry)
        }
        .configurationDisplayName("Battery")
        .description("Charge, power source and the batteries of your accessories.")
        .supportedFamilies([.systemSmall])
    }
}

struct BatteryWidgetView: View {
    let entry: SnapshotEntry

    var body: some View {
        Group {
            if let power = entry.snapshot?.power {
                content(power)
            } else {
                WidgetPlaceholder(entry: entry)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func content(_ power: WidgetSnapshot.Power) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(title: "Battery", entry: entry)
            if power.hasBattery, let charge = power.chargePercent {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().stroke(Color.primary.opacity(0.12), lineWidth: 7)
                        Circle()
                            .trim(from: 0, to: Double(charge) / 100)
                            .stroke(tint(charge, charging: power.isCharging),
                                    style: StrokeStyle(lineWidth: 7, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(charge)")
                            .font(.system(size: 16, weight: .semibold))
                            .monospacedDigit()
                    }
                    .frame(width: 62, height: 62)
                    VStack(alignment: .leading, spacing: 2) {
                        status(power)
                        if let seconds = power.timeRemainingSeconds, !power.externalConnected {
                            Text(duration(seconds))
                        }
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                }
            } else if !power.hasBattery {
                Text("No battery")
                    .font(.system(size: 13, weight: .semibold))
                if power.peripherals.isEmpty {
                    Text("This Mac runs on power")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            VStack(spacing: 5) {
                ForEach(Array(power.peripherals.prefix(2).enumerated()), id: \.offset) { _, device in
                    accessory(device)
                }
            }
        }
    }

    @ViewBuilder
    private func status(_ power: WidgetSnapshot.Power) -> some View {
        if power.isCharging {
            Text("Charging")
        } else if power.externalConnected {
            Text("Plugged in")
        } else {
            Text("On battery")
        }
    }

    private func accessory(_ device: WidgetSnapshot.Peripheral) -> some View {
        HStack(spacing: 6) {
            Text(device.name).lineLimit(1).frame(maxWidth: 62, alignment: .leading)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.12))
                GeometryReader { proxy in
                    Capsule()
                        .fill(tint(device.percent, charging: false))
                        .frame(width: proxy.size.width * CGFloat(device.percent) / 100)
                }
            }
            .frame(height: 5)
            Text("\(device.percent)%")
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
        }
        .font(.system(size: 11))
    }

    private func tint(_ percent: Int, charging: Bool) -> Color {
        if charging { return .green }
        if percent <= 10 { return .red }
        if percent <= 20 { return .orange }
        return .green
    }

    /// "3 h 20 min" from a count of seconds, in the Mac's language.
    private func duration(_ seconds: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = seconds >= 3600 ? [.hour, .minute] : [.minute]
        return formatter.string(from: TimeInterval(max(60, seconds))) ?? ""
    }
}
