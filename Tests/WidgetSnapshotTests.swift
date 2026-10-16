// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// What reaches the desktop widgets: copied text only when the person asked
/// for it, readings a glance can trust, a file the extension can always read
/// back, and a write rate that does not spend the widget's daily budget.
enum WidgetSnapshotTests {
    private static let now = Date(timeIntervalSince1970: 1_792_000_000)

    private static func copy(_ text: String, minutesAgo: Double) -> WidgetSnapshotInputs.ClipboardEntry {
        .init(kind: .text, text: text, copiedAt: now.addingTimeInterval(-minutesAgo * 60))
    }

    static func run(_ suite: TestSuite) {
        clipboardIsOptIn(suite)
        clipboardPreviews(suite)
        readings(suite)
        keepAwakeAndMedia(suite)
        throttle(suite)
        store(suite)
    }

    private static func clipboardIsOptIn(_ suite: TestSuite) {
        var inputs = WidgetSnapshotInputs()
        inputs.clipboard = [copy("conta 1234-5", minutesAgo: 1)]
        let off = WidgetSnapshotBuilder.build(inputs, now: now)
        suite.expect(off.clipboard.isEmpty, "copied text stays out of the shared file while the option is off")
        let encoded = (try? WidgetSnapshotStore.encode(off)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        suite.expect(!encoded.contains("1234"), "nothing of the copy reaches the encoded file while off")

        inputs.showsClipboard = true
        let on = WidgetSnapshotBuilder.build(inputs, now: now)
        suite.expect(on.clipboard.map(\.preview) == ["conta 1234-5"], "the copy shows once the option is on")
    }

    private static func clipboardPreviews(_ suite: TestSuite) {
        var inputs = WidgetSnapshotInputs()
        inputs.showsClipboard = true
        inputs.clipboard = [
            copy("old", minutesAgo: 50),
            copy("first line\n\n   second\tline", minutesAgo: 2),
            copy(String(repeating: "a", count: 200), minutesAgo: 5),
            copy("   \n  ", minutesAgo: 1),
            .init(kind: .files, text: "", filePaths: ["/Users/me/Desktop/Relatório.pdf", "/tmp/b"],
                  copiedAt: now.addingTimeInterval(-600)),
            .init(kind: .image, text: "", copiedAt: now.addingTimeInterval(-30)),
        ]
        let items = WidgetSnapshotBuilder.build(inputs, now: now).clipboard
        suite.expect(items.count == WidgetSnapshotBuilder.maxClipboardItems,
                     "at most three copies leave the app, got \(items.count)")
        suite.expect(items.map(\.kind) == [.image, .text, .text], "newest first, blank copies skipped: \(items.map(\.kind))")
        suite.expect(items.first?.preview == "", "an image carries no content, only its kind")
        suite.expect(items.dropFirst().first?.preview == "first line second line", "line breaks collapse to spaces")
        let long = items.last?.preview ?? ""
        suite.expect(long.count == WidgetSnapshotBuilder.maxPreviewCharacters && long.hasSuffix("…"),
                     "long text is cut to the preview length with an ellipsis, got \(long.count)")
        suite.expect(!items.contains { $0.preview == "old" }, "copies beyond the newest three stay in the app")

        inputs.clipboard = [inputs.clipboard[4]]
        suite.expect(WidgetSnapshotBuilder.build(inputs, now: now).clipboard.first?.preview == "Relatório.pdf",
                     "a file copy shows only the first file's name, never its folder")
    }

    private static func readings(_ suite: TestSuite) {
        var inputs = WidgetSnapshotInputs()
        suite.expect(WidgetSnapshotBuilder.build(inputs, now: now).system == nil,
                     "no readings means no system section rather than zeros")

        inputs.cpuUsage = 0.234
        inputs.gpuUsage = .nan
        inputs.memoryUsed = 6
        inputs.memoryTotal = 8
        inputs.cpuTemperature = 47.6
        inputs.netDownBytesPerSec = -5
        inputs.cpuHistory = (0..<240).map { Double($0) / 240 } + [.infinity]
        let system = WidgetSnapshotBuilder.build(inputs, now: now).system
        suite.expect(system?.cpuPercent == 23, "CPU shows as a whole percent")
        suite.expect(system?.gpuPercent == nil, "a reading that is not a number is left out")
        suite.expect(system?.memoryPercent == 75, "memory is used over total")
        suite.expect(system?.cpuTemperatureCelsius == 48, "temperature rounds to whole degrees")
        suite.expect(system?.netDownBytesPerSec == 0, "a negative rate never reaches the widget")
        let history = system?.cpuHistory ?? []
        suite.expect(history.count == WidgetSnapshotBuilder.historyPoints, "history thins to what the widget draws, got \(history.count)")
        suite.expect(history.last == 98 && history.allSatisfy { (0...100).contains($0) },
                     "the newest reading stays the last point: \(history.suffix(3))")

        inputs.memoryTotal = 0
        suite.expect(WidgetSnapshotBuilder.build(inputs, now: now).system?.memoryPercent == nil,
                     "an unknown total never divides by zero")

        inputs.power = .init(hasBattery: true, chargePercent: 140, isCharging: true, timeRemainingSeconds: -1)
        inputs.peripherals = [("Fone", 64), ("  ", 10), ("Mouse", -3), ("Teclado", 80), ("Caneta", 50)]
        let power = WidgetSnapshotBuilder.build(inputs, now: now).power
        suite.expect(power?.chargePercent == 100, "charge never shows above 100%")
        suite.expect(power?.timeRemainingSeconds == nil, "an unknown estimate is left out")
        suite.expect(power?.peripherals.map(\.name) == ["Fone", "Mouse", "Teclado"],
                     "the first three named devices, unnamed ones skipped: \(power?.peripherals ?? [])")
        suite.expect(power?.peripherals.dropFirst().first?.percent == 0, "a negative percent shows as empty")

        inputs.agentWindows = [.init(label: "5 h", usedPercent: 72.4, resetsAt: now), .init(label: "bad", usedPercent: .nan)]
        suite.expect(WidgetSnapshotBuilder.build(inputs, now: now).agents == nil,
                     "agent usage waits until the history has loaded")
        inputs.agentsLoaded = true
        let agents = WidgetSnapshotBuilder.build(inputs, now: now).agents
        suite.expect(agents?.windows.map(\.usedPercent) == [72], "limit windows round and skip unreadable ones")
    }

    private static func keepAwakeAndMedia(_ suite: TestSuite) {
        var inputs = WidgetSnapshotInputs()
        inputs.keepAwakeEnd = now.addingTimeInterval(3600)
        suite.expect(WidgetSnapshotBuilder.build(inputs, now: now).keepAwake.endsAt == nil,
                     "an inactive session shows no end time left over from the last one")
        inputs.keepAwakeActive = true
        suite.expect(WidgetSnapshotBuilder.build(inputs, now: now).keepAwake.endsAt == inputs.keepAwakeEnd,
                     "an active session keeps its end time")

        inputs.playback = .init(title: "  \n ", artist: "x", isPlaying: true, elapsed: 1, duration: 2, sampledAt: now)
        suite.expect(WidgetSnapshotBuilder.build(inputs, now: now).nowPlaying == nil, "a blank title is no track")
        inputs.playback = .init(title: "Faixa", artist: "Artista", isPlaying: true, elapsed: 500, duration: 245, sampledAt: now)
        let track = WidgetSnapshotBuilder.build(inputs, now: now).nowPlaying
        suite.expect(track?.elapsed == 245, "position never runs past the track's length")
    }

    private static func throttle(_ suite: TestSuite) {
        var throttle = WidgetSnapshotThrottle()
        var inputs = WidgetSnapshotInputs()
        inputs.cpuUsage = 0.2
        let first = WidgetSnapshotBuilder.build(inputs, now: now)
        suite.expect(throttle.shouldWrite(first, now: now), "the first snapshot is written")
        inputs.cpuUsage = 0.3
        suite.expect(!throttle.shouldWrite(WidgetSnapshotBuilder.build(inputs, now: now), now: now.addingTimeInterval(30)),
                     "a steady reading waits for the interval")
        suite.expect(throttle.shouldWrite(first, now: now.addingTimeInterval(61)), "after the interval it is written")

        inputs.keepAwakeActive = true
        suite.expect(throttle.shouldWrite(WidgetSnapshotBuilder.build(inputs, now: now), now: now.addingTimeInterval(62)),
                     "turning Keep Awake on does not wait")
        suite.expect(!throttle.shouldWrite(WidgetSnapshotBuilder.build(inputs, now: now), now: now.addingTimeInterval(63)),
                     "the same state right after is not written again")
        suite.expect(throttle.shouldWrite(WidgetSnapshotBuilder.build(inputs, now: now), now: now.addingTimeInterval(-3600)),
                     "a clock set backwards does not hold writes back")
    }

    private static func store(_ suite: TestSuite) {
        let folder = FileManager.default.temporaryDirectory.appending(path: "vorss-widgets-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }

        var inputs = WidgetSnapshotInputs()
        inputs.cpuUsage = 0.5
        inputs.keepAwakeActive = true
        inputs.keepAwakeEnd = now.addingTimeInterval(1800)
        let snapshot = WidgetSnapshotBuilder.build(inputs, now: now)
        suite.expect(WidgetSnapshotStore.write(snapshot, to: folder), "the snapshot is written into a new folder")
        suite.expect(WidgetSnapshotStore.read(from: folder) == snapshot, "what is read back equals what was written")

        let file = folder.appendingPathComponent(WidgetSnapshot.fileName)
        let mode = (try? FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? Int) ?? -1
        suite.expect(mode == 0o600, "the file is owner-only, got \(String(mode, radix: 8))")

        var future = snapshot
        future.version = WidgetSnapshot.currentVersion + 1
        if let data = try? WidgetSnapshotStore.encode(future) {
            suite.expect(WidgetSnapshotStore.decode(data) == nil, "a file from a newer version is not guessed at")
        } else {
            suite.expect(false, "the future snapshot encodes")
        }
        suite.expect(WidgetSnapshotStore.decode(Data("{\"version\":1".utf8)) == nil, "a damaged file reads as nothing")

        suite.expect(!snapshot.isStale(at: now.addingTimeInterval(WidgetSnapshot.staleAfter)),
                     "a snapshot is current up to the stale limit")
        suite.expect(snapshot.isStale(at: now.addingTimeInterval(WidgetSnapshot.staleAfter + 1)),
                     "past the limit the widget shows it as old")
    }
}
