// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// What the desktop widgets show, written by the app and read by the widget
/// extension. The extension is sandboxed and cannot see the app's memory or
/// its private Application Support files, so this small file in the shared
/// App Group container is the only thing that crosses over.
///
/// Foundation only: the same file compiles into the extension. Keep it to
/// values a glance needs; anything here is readable by the extension process.
struct WidgetSnapshot: Codable, Equatable {
    static let currentVersion = 1
    static let fileName = "widget-snapshot.json"
    /// A snapshot older than this means the app stopped writing (quit or
    /// crashed); widgets grey their freshness badge instead of passing old
    /// numbers off as current.
    static let staleAfter: TimeInterval = 30 * 60

    var version = WidgetSnapshot.currentVersion
    var generatedAt: Date
    var system: System?
    var power: Power?
    var keepAwake: KeepAwake
    var agents: Agents?
    var nowPlaying: NowPlaying?
    /// Empty unless the person turned the clipboard widget on.
    var clipboard: [ClipboardItem] = []

    struct System: Codable, Equatable {
        var cpuPercent: Int?
        /// Oldest first, 0...100, at most `WidgetSnapshotBuilder.historyPoints`.
        var cpuHistory: [Int] = []
        var gpuPercent: Int?
        var memoryPercent: Int?
        var memoryPressure: String?
        var cpuTemperatureCelsius: Int?
        var netDownBytesPerSec: Double?
        var netUpBytesPerSec: Double?
        var diskFreeBytes: UInt64?
    }

    struct Power: Codable, Equatable {
        var hasBattery: Bool
        var chargePercent: Int?
        var isCharging: Bool
        var externalConnected: Bool
        var timeRemainingSeconds: Int?
        var peripherals: [Peripheral] = []
    }

    struct Peripheral: Codable, Equatable {
        var name: String
        var percent: Int
    }

    struct KeepAwake: Codable, Equatable {
        var isActive: Bool
        /// nil while active means indefinite.
        var endsAt: Date?
    }

    struct Agents: Codable, Equatable {
        var windows: [LimitWindow] = []
        var todayTokens: Int?
        var liveSessions: Int
    }

    struct LimitWindow: Codable, Equatable {
        var label: String
        var usedPercent: Int
        var resetsAt: Date?
    }

    struct NowPlaying: Codable, Equatable {
        var title: String
        var artist: String
        var isPlaying: Bool
        var elapsed: TimeInterval
        var duration: TimeInterval
        var sampledAt: Date
    }

    struct ClipboardItem: Codable, Equatable {
        enum Kind: String, Codable { case text, image, files }
        var kind: Kind
        /// Collapsed and truncated text, or the first file name; empty for images.
        var preview: String
        var copiedAt: Date
    }

    func isStale(at now: Date) -> Bool {
        now.timeIntervalSince(generatedAt) > Self.staleAfter
    }
}
