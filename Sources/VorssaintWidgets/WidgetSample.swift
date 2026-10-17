// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Made-up readings for the widget gallery and the placeholder, so a widget
/// can be judged before it is added to the desktop.
enum WidgetSample {
    static func snapshot(at now: Date) -> WidgetSnapshot {
        func event(_ title: String, _ calendar: String, hours: Double, length: Double,
                   red: Double, green: Double, blue: Double) -> WidgetSnapshot.AgendaEvent {
            WidgetSnapshot.AgendaEvent(
                title: title, calendarName: calendar, location: "",
                start: now.addingTimeInterval(hours * 3600),
                end: now.addingTimeInterval((hours + length) * 3600),
                allDay: false, red: red, green: green, blue: blue)
        }
        return WidgetSnapshot(
            generatedAt: now,
            system: WidgetSnapshot.System(
                cpuPercent: 23,
                cpuHistory: [12, 14, 11, 18, 22, 19, 15, 13, 16, 24, 31, 27, 20, 17, 15, 19, 26, 22, 18, 16, 21, 25, 23],
                gpuPercent: 9, memoryPercent: 61, memoryPressure: "normal", cpuTemperatureCelsius: 48,
                netDownBytesPerSec: 4_200_000, netUpBytesPerSec: 600_000, diskFreeBytes: 312_000_000_000),
            keepAwake: WidgetSnapshot.KeepAwake(isActive: false, endsAt: nil),
            agenda: WidgetSnapshot.Agenda(accessGranted: true, events: [
                event("Team sync", "Work", hours: -1.5, length: 1, red: 0.18, green: 0.44, blue: 0.9),
                event("Lunch", "Personal", hours: 0.5, length: 1, red: 0.9, green: 0.28, blue: 0.3),
                event("Design review", "Work", hours: 2, length: 1, red: 0.18, green: 0.44, blue: 0.9),
                event("Cinema", "Personal", hours: 6, length: 2.5, red: 0.78, green: 0.47, blue: 0),
            ]))
    }
}
