// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The desktop cards' words: every language says something of its own for the
/// labels a card cannot do without, and the two formats keep their arguments
/// in the order the code fills them, so a translation cannot swap a count and
/// a time.
enum DesktopWidgetsStringsTests {
    static func run(_ suite: TestSuite) {
        let english = FeatureStrings.desktopWidgets(.enUS)
        for language in AppLanguage.allCases where language != .enUS {
            let text = FeatureStrings.desktopWidgets(language)
            // Words that are the same in many languages (CPU, GPU, Agenda) may
            // match English; the sentences and the plain calendar words may not.
            let own: [(String, String, String)] = [
                ("cardCaption", english.cardCaption, text.cardCaption),
                ("noEventsToday", english.noEventsToday, text.noEventsToday),
                ("nothingTomorrow", english.nothingTomorrow, text.nothingTomorrow),
                ("busy", english.busy, text.busy),
                ("allDay", english.allDay, text.allDay),
            ]
            for (field, base, value) in own {
                suite.expect(value != base, "\(language.rawValue) words \(field) in its own language")
            }
            suite.expect(text.tomorrowFormat.contains("%d") && text.tomorrowFormat.contains("%@")
                             && text.tomorrowFormat.range(of: "%d")!.lowerBound
                                < text.tomorrowFormat.range(of: "%@")!.lowerBound,
                         "\(language.rawValue) puts the count before the time in tomorrowFormat")
            suite.expect(String(format: text.untilFormat, "15:00").contains("15:00"),
                         "\(language.rawValue) shows the end time in untilFormat")
        }
        suite.expect(String(format: english.tomorrowFormat, 2, "10:00") == "Tomorrow: 2, first at 10:00",
                     "the English format reads as written")
        let french = FeatureStrings.desktopWidgets(.fr)
        suite.expect(french.tomorrowCountFormat.contains("\u{00A0}:"),
                     "French keeps a non-breaking space before the colon")
    }
}
