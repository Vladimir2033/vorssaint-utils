// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI
import WidgetKit

struct SystemWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "VorssaintSystem", provider: SnapshotProvider()) { entry in
            SystemWidgetView(entry: entry)
        }
        .configurationDisplayName("System")
        .description("CPU, memory, temperature, network and disk.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct SystemWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    var body: some View {
        Group {
            if let system = entry.snapshot?.system {
                if family == .systemSmall {
                    small(system)
                } else {
                    medium(system)
                }
            } else {
                WidgetPlaceholder(entry: entry)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: Small: two rings and the disk

    private func small(_ system: WidgetSnapshot.System) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(title: "System", entry: entry)
            HStack(spacing: 8) {
                ring(system.cpuPercent, label: "CPU", tint: .accentColor)
                ring(system.memoryPercent, label: "Memory", tint: memoryTint(system.memoryPressure))
            }
            Spacer(minLength: 0)
            HStack {
                if let celsius = system.cpuTemperatureCelsius {
                    Text("\(celsius) °C").foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                if let free = system.diskFreeBytes {
                    Text(WidgetFormat.bytes(free)).fontWeight(.semibold)
                }
            }
            .font(.system(size: 12))
        }
    }

    private func ring(_ percent: Int?, label: LocalizedStringKey, tint: Color) -> some View {
        VStack(spacing: 2) {
            ZStack {
                Circle().stroke(Color.primary.opacity(0.12), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: Double(percent ?? 0) / 100)
                    .stroke(tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(percent.map { "\($0)" } ?? "–")
                    .font(.system(size: 14, weight: .semibold))
                    .monospacedDigit()
            }
            .frame(width: 58, height: 58)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func memoryTint(_ pressure: String?) -> Color {
        switch pressure {
        case "warning": return .orange
        case "critical": return .red
        default: return .green
        }
    }

    // MARK: Medium: CPU with its history, and the rest in rows

    private func medium(_ system: WidgetSnapshot.System) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            WidgetHeader(title: "System", entry: entry)
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(system.cpuPercent.map { "\($0)" } ?? "–")
                            .font(.system(size: 34, weight: .semibold))
                            .monospacedDigit()
                        Text("% CPU")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    if let average = average(system.cpuHistory) {
                        Text("average \(average)%")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Sparkline(values: system.cpuHistory)
                        .frame(maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(spacing: 5) {
                    row("Memory") {
                        HStack(spacing: 4) {
                            Text(system.memoryPercent.map { "\($0)%" } ?? "–").fontWeight(.semibold)
                            pressureBadge(system.memoryPressure)
                        }
                    }
                    row("Temperature") {
                        Text(system.cpuTemperatureCelsius.map { "\($0) °C" } ?? "–").fontWeight(.semibold)
                    }
                    row("Network") {
                        Text("↓ \(system.netDownBytesPerSec.map(WidgetFormat.rate) ?? "–")")
                            .fontWeight(.semibold)
                    }
                    row("Disk") {
                        Text(system.diskFreeBytes.map(WidgetFormat.bytes) ?? "–").fontWeight(.semibold)
                    }
                    row("GPU") {
                        Text(system.gpuPercent.map { "\($0)%" } ?? "–").fontWeight(.semibold)
                    }
                }
                .font(.system(size: 12))
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func row<Value: View>(_ title: LocalizedStringKey, @ViewBuilder value: () -> Value) -> some View {
        HStack(spacing: 6) {
            Text(title).foregroundStyle(.secondary).lineLimit(1)
            Spacer(minLength: 2)
            value().lineLimit(1).minimumScaleFactor(0.8)
        }
    }

    @ViewBuilder
    private func pressureBadge(_ pressure: String?) -> some View {
        switch pressure {
        case "normal": badge("normal", .green)
        case "warning": badge("warning", .orange)
        case "critical": badge("critical", .red)
        default: EmptyView()
        }
    }

    private func badge(_ text: LocalizedStringKey, _ tint: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 5))
    }

    private func average(_ values: [Int]) -> Int? {
        guard values.count >= 3 else { return nil }
        return Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
    }
}

/// The CPU history as a line over a soft fill, newest point on the right.
struct Sparkline: View {
    let values: [Int]

    var body: some View {
        GeometryReader { proxy in
            let points = positions(in: proxy.size)
            if points.count > 1, let first = points.first, let last = points.last {
                ZStack {
                    Path { path in
                        path.move(to: CGPoint(x: first.x, y: proxy.size.height))
                        for point in points { path.addLine(to: point) }
                        path.addLine(to: CGPoint(x: last.x, y: proxy.size.height))
                        path.closeSubpath()
                    }
                    .fill(Color.accentColor.opacity(0.18))
                    Path { path in
                        path.move(to: first)
                        for point in points.dropFirst() { path.addLine(to: point) }
                    }
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 5, height: 5)
                        .position(last)
                }
            }
        }
    }

    /// Scaled to the larger of 40% and the highest reading, so a quiet
    /// machine still draws a readable line instead of a flat one.
    private func positions(in size: CGSize) -> [CGPoint] {
        guard values.count > 1, size.width > 0, size.height > 0 else { return [] }
        let ceiling = Double(max(40, values.max() ?? 40))
        let step = size.width / CGFloat(values.count - 1)
        return values.enumerated().map { index, value in
            let fraction = min(1, max(0, Double(value) / ceiling))
            return CGPoint(x: CGFloat(index) * step, y: size.height - CGFloat(fraction) * (size.height - 6) - 3)
        }
    }
}
