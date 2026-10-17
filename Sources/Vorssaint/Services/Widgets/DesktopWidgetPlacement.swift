// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Foundation

/// The cards Vorssaint can draw on the desktop. The raw value keys the saved
/// position, so a case is never renamed.
enum DesktopWidgetKind: String, CaseIterable {
    case system, systemCompact, systemDetailed, agenda, nextEvent, calendarMonth, worldClock, accessories

    /// The switch that turns the card on.
    var defaultsKey: String {
        switch self {
        case .system: return DefaultsKey.desktopWidgetSystem
        case .systemCompact: return DefaultsKey.desktopWidgetSystemCompact
        case .systemDetailed: return DefaultsKey.desktopWidgetSystemDetailed
        case .agenda: return DefaultsKey.desktopWidgetAgenda
        case .nextEvent: return DefaultsKey.desktopWidgetNextEvent
        case .calendarMonth: return DefaultsKey.desktopWidgetCalendarMonth
        case .worldClock: return DefaultsKey.desktopWidgetWorldClock
        case .accessories: return DefaultsKey.desktopWidgetAccessories
        }
    }

    /// Cards drawing the system readings; while one is on, the monitor
    /// samples at the panel's pace.
    var readsSystem: Bool { self == .system || self == .systemCompact || self == .systemDetailed }
    var readsCalendar: Bool { self == .agenda || self == .nextEvent || self == .calendarMonth }

    /// The size the card is designed at, in points: the small, medium and
    /// large cells macOS's own widgets use, so the cards sit well beside them.
    var size: CGSize {
        switch self {
        case .system, .worldClock: return CGSize(width: 364, height: 170)
        case .systemCompact, .nextEvent, .accessories: return CGSize(width: 170, height: 170)
        case .systemDetailed, .agenda: return CGSize(width: 364, height: 382)
        case .calendarMonth: return CGSize(width: 364, height: 470)
        }
    }
}

/// Where each card goes. Pure geometry in AppKit's coordinates (origin at the
/// bottom left), so a test can place cards on screens it makes up.
enum DesktopWidgetPlacement {
    static let margin: CGFloat = 24
    static let gap: CGFloat = 16
    /// Of a saved position, this much of the card must still be on a screen
    /// for it to count: a display unplugged since leaves it out of reach.
    static let minimumVisible: CGFloat = 60

    /// Cards in columns from the top right of `visible`, each new one under
    /// the last, a new column to the left when the column is full. `enabled`
    /// fixes the order, so turning a card on never moves the others.
    static func defaultOrigins(for enabled: [DesktopWidgetKind], in visible: CGRect) -> [DesktopWidgetKind: CGPoint] {
        var origins: [DesktopWidgetKind: CGPoint] = [:]
        var right = visible.maxX - margin
        var top = visible.maxY - margin
        var columnWidth: CGFloat = 0
        for kind in DesktopWidgetKind.allCases where enabled.contains(kind) {
            let size = kind.size
            if top - size.height < visible.minY + margin, columnWidth > 0 {
                right -= columnWidth + gap
                top = visible.maxY - margin
                columnWidth = 0
            }
            origins[kind] = CGPoint(x: right - size.width, y: top - size.height)
            top -= size.height + gap
            columnWidth = max(columnWidth, size.width)
        }
        return origins
    }

    /// The saved position when enough of the card would be on a screen, else
    /// nil and the caller falls back to the default.
    static func usable(_ origin: CGPoint, size: CGSize, screens: [CGRect]) -> CGPoint? {
        guard origin.x.isFinite, origin.y.isFinite else { return nil }
        let card = CGRect(origin: origin, size: size)
        let enough = screens.contains { screen in
            let overlap = card.intersection(screen)
            return !overlap.isNull && overlap.width >= minimumVisible && overlap.height >= minimumVisible
        }
        return enough ? origin : nil
    }

    static func format(_ origin: CGPoint) -> String {
        "\(Int(origin.x.rounded())),\(Int(origin.y.rounded()))"
    }

    static func parse(_ text: String) -> CGPoint? {
        let parts = text.split(separator: ",", omittingEmptySubsequences: false)
        guard parts.count == 2, let x = Double(parts[0]), let y = Double(parts[1]),
              x.isFinite, y.isFinite else { return nil }
        return CGPoint(x: x, y: y)
    }

    /// Every card's origin: the saved one if still on a screen, else its place
    /// in the default stack.
    static func origins(for enabled: [DesktopWidgetKind], saved: [String: String],
                        screens: [CGRect], primary: CGRect) -> [DesktopWidgetKind: CGPoint] {
        let defaults = defaultOrigins(for: enabled, in: primary)
        var result: [DesktopWidgetKind: CGPoint] = [:]
        for kind in enabled {
            if let text = saved[kind.rawValue], let point = parse(text),
               let kept = usable(point, size: kind.size, screens: screens) {
                result[kind] = kept
            } else if let fallback = defaults[kind] {
                result[kind] = fallback
            }
        }
        return result
    }
}
