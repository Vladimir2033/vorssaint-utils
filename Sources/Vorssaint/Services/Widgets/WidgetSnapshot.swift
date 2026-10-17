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
    var agenda: Agenda?
    var nowPlaying: NowPlaying?
    /// Empty unless the person turned the clipboard widget on.
    var clipboard: [ClipboardItem] = []

    struct System: Codable, Equatable {
        var cpuPercent: Int?
        /// Oldest first, 0...100, one point per snapshot write (about a
        /// minute apart), at most `WidgetSnapshotBuilder.historyPoints`. It
        /// restarts empty with the app: it is what the app has seen, not a
        /// log kept on disk.
        var cpuHistory: [Int] = []
        var gpuPercent: Int?
        var memoryPercent: Int?
        var memoryPressure: String?
        var cpuTemperatureCelsius: Int?
        var netDownBytesPerSec: Double?
        var netUpBytesPerSec: Double?
        var diskFreeBytes: UInt64?
        var diskTotalBytes: UInt64?
        /// Same spacing and length as `cpuHistory`.
        var memoryHistory: [Int] = []
        var gpuHistory: [Int] = []
        var netDownHistory: [Double] = []
        var netUpHistory: [Double] = []
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
        /// "keyboard", "mouse", "trackpad", "audio" or "device", for the icon.
        var kind: String = "device"
    }

    struct KeepAwake: Codable, Equatable {
        var isActive: Bool
        /// nil while active means indefinite.
        var endsAt: Date?

        /// A session that ended while the app was closed is over, whatever the
        /// last snapshot said.
        func isOn(at now: Date) -> Bool {
            guard isActive else { return false }
            if let endsAt { return endsAt > now }
            return true
        }
    }

    struct Agents: Codable, Equatable {
        var windows: [LimitWindow] = []
        var todayTokens: Int?
        var liveSessions: Int
    }

    /// One allowance an agent reports. The widget words it from these parts
    /// so the kind can follow the Mac's language while the product name stays.
    struct LimitWindow: Codable, Equatable {
        var provider: String
        /// "session", "weekly" or "other".
        var kind: String
        var minutes: Int?
        var usedPercent: Int
        var resetsAt: Date?
    }

    /// Today's and tomorrow's events, already filtered by the calendars the
    /// person left out of the island. `accessGranted` false means the app has
    /// no calendar permission, which the widget tells apart from an empty day.
    struct Agenda: Codable, Equatable {
        var accessGranted: Bool
        var events: [AgendaEvent] = []
    }

    struct AgendaEvent: Codable, Equatable {
        /// Empty when the person chose to keep event titles off the desk.
        var title: String
        var calendarName: String
        /// Empty when titles are kept off the desk.
        var location: String
        var start: Date
        var end: Date
        var allDay: Bool
        /// The calendar's colour, 0...1.
        var red: Double
        var green: Double
        var blue: Double
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
