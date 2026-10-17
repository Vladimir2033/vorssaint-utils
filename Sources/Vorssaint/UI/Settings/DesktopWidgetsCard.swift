// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import EventKit
import SwiftUI

/// The switches for the cards Vorssaint draws on the desktop. It sits on the
/// Monitor page, where the readings the System cards show are chosen.
struct DesktopWidgetsCard: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @AppStorage(DefaultsKey.desktopWidgetSystem) private var system = false
    @AppStorage(DefaultsKey.desktopWidgetSystemCompact) private var systemCompact = false
    @AppStorage(DefaultsKey.desktopWidgetAgenda) private var agenda = false
    @AppStorage(DefaultsKey.desktopWidgetNextEvent) private var nextEvent = false
    @AppStorage(DefaultsKey.widgetCalendarShowsTitles) private var showsTitles = true

    private var strings: DesktopWidgetsFeatureStrings { FeatureStrings.desktopWidgets(l10n.language) }
    private var usesCalendar: Bool { agenda || nextEvent }
    private var anyOn: Bool { system || systemCompact || agenda || nextEvent }

    var body: some View {
        SettingsCard {
            Text(strings.cardCaption)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            switchRow("gauge.with.dots.needle.67percent", strings.system, $system)
            switchRow("gauge.with.dots.needle.33percent", strings.systemCompact, $systemCompact)
            switchRow("calendar", strings.agenda, $agenda)
            switchRow("calendar.badge.clock", strings.nextEvent, $nextEvent)
            if usesCalendar {
                SettingsRow(symbol: "text.alignleft", title: strings.showTitles,
                            caption: strings.showTitlesCaption) {
                    Toggle(strings.showTitles, isOn: $showsTitles).labelsHidden()
                }
                if permissions.calendarAccess != .fullAccess {
                    HStack(spacing: 10) {
                        Text(strings.noCalendarAccess)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button(strings.allowCalendar) { permissions.requestCalendar() }
                    }
                    .padding(.leading, settingsRowTextInset)
                }
            }
            if anyOn {
                Button(strings.resetPositions) { DesktopWidgetsService.shared.resetPositions() }
            }
        }
    }

    private func switchRow(_ symbol: String, _ title: String, _ isOn: Binding<Bool>) -> some View {
        SettingsRow(symbol: symbol, title: title) {
            Toggle(title, isOn: isOn)
                .labelsHidden()
                .onChange(of: isOn.wrappedValue) { _, _ in
                    DesktopWidgetsService.shared.syncWithPreferences()
                }
        }
    }
}
