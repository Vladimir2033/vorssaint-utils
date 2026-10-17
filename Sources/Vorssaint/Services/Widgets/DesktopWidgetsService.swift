// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine
import EventKit
import SwiftUI

/// One desktop card. A subclass of the app's overlay panel so tiling window
/// managers leave it alone, like the Shelf.
final class DesktopWidgetPanel: OverlayPanel {}

/// Draws the cards the person turned on, directly on the desktop: behind every
/// window, above the wallpaper and the desktop icons, on every Space. They are
/// the app's own windows, not macOS widgets, so they need no extension, no
/// signing beyond the app's and no App Group, and they refresh in place.
///
/// The readings come from the services the app already runs. The monitor is
/// asked for the widgets' readings only while a card is on, and never for the
/// accessories' Bluetooth batteries.
@MainActor
final class DesktopWidgetsService {
    static let shared = DesktopWidgetsService()

    let model = DesktopWidgetsModel()
    private let collector = WidgetSnapshotCollector()
    private var panels: [DesktopWidgetKind: DesktopWidgetPanel] = [:]
    private var moveTokens: [DesktopWidgetKind: NSObjectProtocol] = [:]
    private var pendingSaves: [DesktopWidgetKind: DispatchWorkItem] = [:]
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var permissionSubscription: AnyCancellable?
    private var ticks = 0
    private var collecting = false
    private var calendarDirty = true

    /// How often the cards redraw. The readings themselves come at the
    /// monitor's slower background pace; this keeps "now" and "past" current.
    private static let tick: TimeInterval = 5
    /// One CPU point and one calendar read per this many ticks (a minute).
    private static let slowEvery = 12

    private init() {}

    static func isEnabled(_ kind: DesktopWidgetKind, in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: kind.defaultsKey)
    }

    /// Makes the windows match the switches: idempotent, so it runs at launch
    /// and after every change in Settings.
    func syncWithPreferences() {
        let enabled = DesktopWidgetKind.allCases.filter { Self.isEnabled($0) }
        guard !enabled.isEmpty else { stop(); return }
        for kind in panels.keys where !enabled.contains(kind) { close(kind) }
        let missing = enabled.filter { panels[$0] == nil }
        if !missing.isEmpty {
            let origins = DesktopWidgetPlacement.origins(
                for: enabled, saved: savedOrigins(), screens: screenFrames(), primary: primaryFrame())
            for kind in missing {
                guard let origin = origins[kind] else { continue }
                open(kind, at: origin)
            }
        }
        startUpdating()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        permissionSubscription = nil
        for kind in Array(panels.keys) { close(kind) }
        SystemMonitor.shared.setWidgetsMonitoring(false, consumer: "desktop")
        calendarDirty = true
    }

    /// Back to the default stack, forgetting where cards were dragged.
    func resetPositions() {
        UserDefaults.standard.removeObject(forKey: DefaultsKey.desktopWidgetOrigins)
        let enabled = DesktopWidgetKind.allCases.filter { panels[$0] != nil }
        let origins = DesktopWidgetPlacement.defaultOrigins(for: enabled, in: primaryFrame())
        for (kind, origin) in origins { panels[kind]?.setFrameOrigin(origin) }
    }

    // MARK: Windows

    private func open(_ kind: DesktopWidgetKind, at origin: CGPoint) {
        let panel = DesktopWidgetPanel(contentRect: CGRect(origin: origin, size: kind.size),
                                       styleMask: [.borderless, .nonactivatingPanel],
                                       backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        // Just above the desktop icons, so every app window covers the card.
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isMovableByWindowBackground = true
        panel.contentView = NSHostingView(rootView: DesktopWidgetRoot(kind: kind, model: model))
        panel.setFrame(CGRect(origin: origin, size: kind.size), display: false)
        panel.orderFrontRegardless()
        panels[kind] = panel
        moveTokens[kind] = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: panel, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.scheduleSave(kind) }
        }
    }

    private func close(_ kind: DesktopWidgetKind) {
        pendingSaves.removeValue(forKey: kind)?.cancel()
        if let token = moveTokens.removeValue(forKey: kind) { NotificationCenter.default.removeObserver(token) }
        panels.removeValue(forKey: kind)?.close()
    }

    /// A drag is a stream of moves; the spot is saved once it settles.
    private func scheduleSave(_ kind: DesktopWidgetKind) {
        pendingSaves[kind]?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.saveOrigin(of: kind) }
        }
        pendingSaves[kind] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func saveOrigin(of kind: DesktopWidgetKind) {
        guard let panel = panels[kind] else { return }
        var saved = savedOrigins()
        saved[kind.rawValue] = DesktopWidgetPlacement.format(panel.frame.origin)
        UserDefaults.standard.set(saved, forKey: DefaultsKey.desktopWidgetOrigins)
    }

    private func savedOrigins() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: DefaultsKey.desktopWidgetOrigins) as? [String: String] ?? [:]
    }

    private func screenFrames() -> [CGRect] { NSScreen.screens.map(\.visibleFrame) }

    private func primaryFrame() -> CGRect {
        NSScreen.screens.first?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
    }

    /// A display unplugged or rearranged can leave a card out of reach.
    private func keepCardsReachable() {
        let enabled = DesktopWidgetKind.allCases.filter { panels[$0] != nil }
        let defaults = DesktopWidgetPlacement.defaultOrigins(for: enabled, in: primaryFrame())
        for (kind, panel) in panels {
            if DesktopWidgetPlacement.usable(panel.frame.origin, size: kind.size, screens: screenFrames()) == nil,
               let origin = defaults[kind] {
                panel.setFrameOrigin(origin)
            }
        }
    }

    // MARK: Data

    private func startUpdating() {
        guard timer == nil else { return }
        SystemMonitor.shared.setWidgetsMonitoring(true, consumer: "desktop")
        let timer = Timer(timeInterval: Self.tick, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        timer.tolerance = 1
        // The panel's tracking loop would otherwise pause the timer while open.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        // What changes the calendar, or the day, is read at once.
        for name in [Notification.Name.EKEventStoreChanged, .NSSystemClockDidChange,
                     .NSSystemTimeZoneDidChange, .NSCalendarDayChanged] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) {
                [weak self] _ in
                Task { @MainActor in
                    self?.calendarDirty = true
                    self?.refresh()
                }
            })
        }
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) {
            [weak self] _ in
            Task { @MainActor in self?.keepCardsReachable() }
        })
        permissionSubscription = Permissions.shared.$calendarAccess.removeDuplicates().dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.calendarDirty = true
                    self?.refresh()
                }
            }
        ticks = 0
        calendarDirty = true
        refresh()
    }

    private func refresh() {
        guard timer != nil, !collecting else { return }
        collecting = true
        let slow = ticks % Self.slowEvery == 0
        let readsAgenda = slow || calendarDirty
        calendarDirty = false
        ticks += 1
        Task { [weak self] in
            guard let self else { return }
            let snapshot = await self.collector.collect(recordsHistory: slow, readsAgenda: readsAgenda)
            self.collecting = false
            guard self.timer != nil else { return }
            self.model.snapshot = snapshot
            self.model.now = Date()
        }
    }
}
