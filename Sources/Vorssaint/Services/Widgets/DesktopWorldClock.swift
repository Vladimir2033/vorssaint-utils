// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The world clock's choices and labels, pure so a test can pin them with
/// time zones it picks. All local: nothing is looked up online.
enum DesktopWorldClock {
    static let maxClocks = 4

    /// The zones to draw, in the person's order: unknown and repeated
    /// identifiers dropped, at most four, and this Mac's own zone when the
    /// list is empty, so the card never draws nothing.
    static func zones(from identifiers: [String]?, local: TimeZone = .current) -> [TimeZone] {
        var seen = Set<String>()
        let zones = (identifiers ?? []).compactMap { identifier -> TimeZone? in
            guard seen.insert(identifier).inserted else { return nil }
            return TimeZone(identifier: identifier)
        }
        return zones.isEmpty ? [local] : Array(zones.prefix(maxClocks))
    }

    /// "America/Sao_Paulo" reads "Sao Paulo": the last part of the identifier,
    /// which names the city the zone is known by.
    static func cityName(_ zone: TimeZone) -> String {
        let last = zone.identifier.split(separator: "/").last.map(String.init) ?? zone.identifier
        return last.replacingOccurrences(of: "_", with: " ")
    }

    /// -1 when it is still yesterday in `zone`, 1 when it is already tomorrow.
    static func dayShift(at date: Date, in zone: TimeZone, local: TimeZone = .current) -> Int {
        func dayNumber(_ timeZone: TimeZone) -> Int? {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            var utc = Calendar(identifier: .gregorian)
            utc.timeZone = TimeZone(secondsFromGMT: 0) ?? timeZone
            guard let day = utc.date(from: parts) else { return nil }
            return Int((day.timeIntervalSince1970 / 86_400).rounded(.down))
        }
        guard let there = dayNumber(zone), let here = dayNumber(local) else { return 0 }
        return max(-1, min(1, there - here))
    }

    /// "+3 h", "−5 h", "+5:30 h" from this Mac's clock; empty for the same time.
    static func offsetText(at date: Date, in zone: TimeZone, local: TimeZone = .current) -> String {
        let seconds = zone.secondsFromGMT(for: date) - local.secondsFromGMT(for: date)
        guard seconds != 0 else { return "" }
        let sign = seconds > 0 ? "+" : "\u{2212}"
        let hours = abs(seconds) / 3600
        let minutes = abs(seconds) % 3600 / 60
        return minutes == 0 ? "\(sign)\(hours) h" : "\(sign)\(hours):" + String(format: "%02d", minutes) + " h"
    }

    /// Zones whose city matches `query`, ignoring case and accents, for the
    /// picker in Settings; the ones already chosen are left out.
    static func search(_ query: String, excluding chosen: [String], limit: Int = 6,
                       identifiers: [String] = TimeZone.knownTimeZoneIdentifiers) -> [String] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        guard !needle.isEmpty else { return [] }
        return identifiers.filter { identifier in
            guard !chosen.contains(identifier), let zone = TimeZone(identifier: identifier) else { return false }
            return cityName(zone).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
                .contains(needle)
        }
        .prefix(limit)
        .map { $0 }
    }
}
