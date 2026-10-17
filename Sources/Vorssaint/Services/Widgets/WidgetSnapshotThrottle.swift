// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Decides when a fresh snapshot is worth a disk write and a timeline reload.
///
/// macOS gives each widget a daily reload budget and ignores requests past
/// it, so asking every 2 s (the system monitor's tick) would spend the budget
/// by mid-morning and leave the widget frozen for the rest of the day. Steady
/// readings are written at most once a minute; a change the person would
/// notice on the desk right away (Keep Awake toggled, another track, a new
/// copy) goes through immediately.
struct WidgetSnapshotThrottle {
    static let minimumInterval: TimeInterval = 60

    /// The parts of a snapshot whose change should not wait for the interval.
    struct Signature: Equatable {
        var keepAwakeActive: Bool
        var keepAwakeEndsAt: Date?
        var trackTitle: String?
        var isPlaying: Bool
        var latestCopyAt: Date?
        /// Start and end of every event, so an edited, added or removed event
        /// reaches the desk at once instead of after the interval.
        var agendaStamp: [TimeInterval]
        var agendaAccess: Bool?

        init(_ snapshot: WidgetSnapshot) {
            keepAwakeActive = snapshot.keepAwake.isActive
            keepAwakeEndsAt = snapshot.keepAwake.endsAt
            trackTitle = snapshot.nowPlaying?.title
            isPlaying = snapshot.nowPlaying?.isPlaying ?? false
            latestCopyAt = snapshot.clipboard.first?.copiedAt
            agendaStamp = (snapshot.agenda?.events ?? []).flatMap {
                [$0.start.timeIntervalSince1970, $0.end.timeIntervalSince1970]
            }
            agendaAccess = snapshot.agenda?.accessGranted
        }
    }

    private(set) var lastWrite: Date?
    private(set) var lastSignature: Signature?

    /// True when `snapshot` should be written now; records the write when it is.
    mutating func shouldWrite(_ snapshot: WidgetSnapshot, now: Date) -> Bool {
        let signature = Signature(snapshot)
        let due: Bool
        if let lastWrite, let lastSignature {
            let elapsed = now.timeIntervalSince(lastWrite)
            // A clock set backwards would otherwise hold every write until it
            // caught up again, possibly for hours.
            due = signature != lastSignature || elapsed >= Self.minimumInterval || elapsed < 0
        } else {
            due = true
        }
        if due {
            lastWrite = now
            lastSignature = signature
        }
        return due
    }
}

/// Reads and writes the snapshot file inside the App Group container.
enum WidgetSnapshotStore {
    static func encode(_ snapshot: WidgetSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(snapshot)
    }

    /// nil for a missing file, a damaged one or one from a newer app version:
    /// the widget then shows its placeholder rather than guessing.
    static func decode(_ data: Data) -> WidgetSnapshot? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let snapshot = try? decoder.decode(WidgetSnapshot.self, from: data),
              snapshot.version <= WidgetSnapshot.currentVersion
        else { return nil }
        return snapshot
    }

    /// Owner-only and atomic, so the extension never reads half a file.
    @discardableResult
    static func write(_ snapshot: WidgetSnapshot, to directory: URL) -> Bool {
        guard let data = try? encode(snapshot),
              PrivateFileStore.createDirectory(at: directory, container: directory)
        else { return false }
        return PrivateFileStore.write(data, to: directory.appendingPathComponent(WidgetSnapshot.fileName))
    }

    static func read(from directory: URL) -> WidgetSnapshot? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(WidgetSnapshot.fileName))
        else { return nil }
        return decode(data)
    }
}
