// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The world clock never draws an empty card or a zone it does not know,
/// says the day there right across the date line, and finds a city however
/// it is typed.
enum DesktopWorldClockTests {
    private static let saoPaulo = TimeZone(identifier: "America/Sao_Paulo")!
    private static let tokyo = TimeZone(identifier: "Asia/Tokyo")!
    private static let honolulu = TimeZone(identifier: "Pacific/Honolulu")!
    private static let kolkata = TimeZone(identifier: "Asia/Kolkata")!

    static func run(_ suite: TestSuite) {
        let zones = DesktopWorldClock.zones(from: ["Asia/Tokyo", "Nowhere/Land", "Asia/Tokyo", "Europe/London",
                                                   "America/New_York", "Australia/Sydney", "Africa/Cairo"],
                                            local: saoPaulo)
        suite.expect(zones.map(\.identifier) == ["Asia/Tokyo", "Europe/London", "America/New_York", "Australia/Sydney"],
                     "unknown and repeated zones are dropped and four are kept: \(zones.map(\.identifier))")
        suite.expect(DesktopWorldClock.zones(from: [], local: saoPaulo) == [saoPaulo],
                     "an empty list shows this Mac's own zone")
        suite.expect(DesktopWorldClock.zones(from: nil, local: saoPaulo) == [saoPaulo], "no list shows this Mac's zone")

        suite.expect(DesktopWorldClock.cityName(saoPaulo) == "Sao Paulo", "the city reads without underscores")

        // 23:00 on 17 October in São Paulo (UTC−3) is 02:00 UTC on the 18th.
        let lateEvening = Date(timeIntervalSince1970: 1_792_288_800)
        suite.expect(DesktopWorldClock.dayShift(at: lateEvening, in: tokyo, local: saoPaulo) == 1,
                     "Tokyo is already tomorrow late in the São Paulo evening")
        suite.expect(DesktopWorldClock.dayShift(at: lateEvening, in: saoPaulo, local: saoPaulo) == 0, "home is today")
        // 01:00 on 18 October in São Paulo is still the 17th in Honolulu.
        let earlyMorning = Date(timeIntervalSince1970: 1_792_296_000)
        suite.expect(DesktopWorldClock.dayShift(at: earlyMorning, in: honolulu, local: saoPaulo) == -1,
                     "Honolulu is still yesterday early in the São Paulo morning")

        suite.expect(DesktopWorldClock.offsetText(at: lateEvening, in: tokyo, local: saoPaulo) == "+12 h",
                     "Tokyo is twelve hours ahead")
        suite.expect(DesktopWorldClock.offsetText(at: lateEvening, in: honolulu, local: saoPaulo) == "\u{2212}7 h",
                     "Honolulu is seven hours behind")
        suite.expect(DesktopWorldClock.offsetText(at: lateEvening, in: kolkata, local: saoPaulo) == "+8:30 h",
                     "a half-hour zone shows its minutes")
        suite.expect(DesktopWorldClock.offsetText(at: lateEvening, in: saoPaulo, local: saoPaulo).isEmpty,
                     "the same zone has no offset")

        let found = DesktopWorldClock.search("são", excluding: [])
        suite.expect(found.contains("America/Sao_Paulo"), "a city is found with its accent typed: \(found)")
        suite.expect(DesktopWorldClock.search("TOKYO", excluding: ["Asia/Tokyo"]).isEmpty,
                     "a city already chosen is not offered again")
        suite.expect(DesktopWorldClock.search("  ", excluding: []).isEmpty, "a blank search offers nothing")
        suite.expect(DesktopWorldClock.search("a", excluding: []).count <= 6, "the list stays short")
    }
}
