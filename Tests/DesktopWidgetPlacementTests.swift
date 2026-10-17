// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Foundation

/// Where the desktop cards land: stacked from the top right without
/// overlapping, never lost off a screen, and each one kept where it was
/// dragged. A card that cannot be reached is worse than one in a default spot.
enum DesktopWidgetPlacementTests {
    private static let screen = CGRect(x: 0, y: 0, width: 1600, height: 1000)

    static func run(_ suite: TestSuite) {
        stack(suite)
        saved(suite)
        text(suite)
    }

    private static func stack(_ suite: TestSuite) {
        let all = DesktopWidgetKind.allCases
        let origins = DesktopWidgetPlacement.defaultOrigins(for: all, in: screen)
        suite.expect(origins.count == all.count, "every enabled card gets a place")
        let frames = all.compactMap { kind in origins[kind].map { CGRect(origin: $0, size: kind.size) } }
        var overlaps = 0
        for first in frames.indices {
            for second in frames.indices where second > first && frames[first].intersects(frames[second]) {
                overlaps += 1
            }
        }
        suite.expect(overlaps == 0, "no two cards overlap by default, \(overlaps) do")
        suite.expect(frames.allSatisfy { screen.contains($0) }, "every default place is on the screen")
        let system = origins[.system]
        suite.expect(system?.x == screen.maxX - DesktopWidgetPlacement.margin - DesktopWidgetKind.system.size.width
                         && system?.y == screen.maxY - DesktopWidgetPlacement.margin - DesktopWidgetKind.system.size.height,
                     "the first card sits in the top right corner: \(String(describing: system))")

        let withoutSystem = DesktopWidgetPlacement.defaultOrigins(for: [.agenda], in: screen)
        let withSystem = DesktopWidgetPlacement.defaultOrigins(for: [.system, .agenda], in: screen)
        suite.expect(withoutSystem[.agenda] != nil && withSystem[.agenda] != nil
                         && withSystem[.agenda]!.y < withoutSystem[.agenda]!.y,
                     "a card turned on pushes the ones after it down, not the ones before it")

        let short = CGRect(x: 0, y: 0, width: 1600, height: 600)
        let crowded = DesktopWidgetPlacement.defaultOrigins(for: [.system, .agenda], in: short)
        suite.expect(crowded[.system] != nil && crowded[.agenda] != nil
                         && crowded[.agenda]!.x < crowded[.system]!.x,
                     "a column that is full continues in a new column to the left")
    }

    private static func saved(_ suite: TestSuite) {
        let size = DesktopWidgetKind.system.size
        suite.expect(DesktopWidgetPlacement.usable(CGPoint(x: 100, y: 100), size: size, screens: [screen]) != nil,
                     "a card on the screen is kept where it was left")
        suite.expect(DesktopWidgetPlacement.usable(CGPoint(x: 5000, y: 100), size: size, screens: [screen]) == nil,
                     "a card left on a display that is gone is not kept")
        suite.expect(DesktopWidgetPlacement.usable(CGPoint(x: 1570, y: 100), size: size, screens: [screen]) == nil,
                     "a card with only a sliver on screen cannot be grabbed, so it is not kept")
        suite.expect(DesktopWidgetPlacement.usable(CGPoint(x: .nan, y: 0), size: size, screens: [screen]) == nil,
                     "a position that is not a number is not kept")
        let second = CGRect(x: 1600, y: 0, width: 1000, height: 800)
        suite.expect(DesktopWidgetPlacement.usable(CGPoint(x: 2000, y: 100), size: size, screens: [screen, second]) != nil,
                     "a card on a second display is kept")

        let placed = DesktopWidgetPlacement.origins(
            for: [.system, .agenda],
            saved: [DesktopWidgetKind.system.rawValue: "120,340", DesktopWidgetKind.agenda.rawValue: "9999,9999"],
            screens: [screen], primary: screen)
        suite.expect(placed[.system] == CGPoint(x: 120, y: 340), "a saved position wins over the default")
        suite.expect(placed[.agenda] == DesktopWidgetPlacement.defaultOrigins(for: [.system, .agenda], in: screen)[.agenda],
                     "an unreachable saved position falls back to the card's default place")
    }

    private static func text(_ suite: TestSuite) {
        suite.expect(DesktopWidgetPlacement.format(CGPoint(x: 120.4, y: -30.6)) == "120,-31", "a position is written as whole points")
        suite.expect(DesktopWidgetPlacement.parse("120,-31") == CGPoint(x: 120, y: -31), "a written position reads back")
        for bad in ["", "1", "1,2,3", "a,b", "1,", ",2", "nan,1", "inf,1"] {
            suite.expect(DesktopWidgetPlacement.parse(bad) == nil, "\"\(bad)\" is not a position")
        }
    }
}
