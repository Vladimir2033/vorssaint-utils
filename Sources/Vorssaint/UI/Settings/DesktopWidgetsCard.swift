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
    @AppStorage(DefaultsKey.desktopWidgetSystemDetailed) private var systemDetailed = false
    @AppStorage(DefaultsKey.desktopWidgetAgenda) private var agenda = false
    @AppStorage(DefaultsKey.desktopWidgetNextEvent) private var nextEvent = false
    @AppStorage(DefaultsKey.desktopWidgetCalendarMonth) private var calendarMonth = false
    @AppStorage(DefaultsKey.desktopWidgetWorldClock) private var worldClock = false
    @AppStorage(DefaultsKey.desktopWidgetAccessories) private var accessories = false
    @AppStorage(DefaultsKey.widgetCalendarShowsTitles) private var showsTitles = true
    @State private var clocks: [String] = UserDefaults.standard.stringArray(forKey: DefaultsKey.desktopWidgetClocks) ?? []
    @State private var citySearch = ""

    private var strings: DesktopWidgetsFeatureStrings { FeatureStrings.desktopWidgets(l10n.language) }
    private var usesCalendar: Bool { agenda || nextEvent || calendarMonth }
    private var anyOn: Bool {
        system || systemCompact || systemDetailed || agenda || nextEvent || calendarMonth || worldClock || accessories
    }

    var body: some View {
        SettingsCard {
            Text(strings.cardCaption)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            switchRow("gauge.with.dots.needle.67percent", strings.system, $system)
            switchRow("gauge.with.dots.needle.33percent", strings.systemCompact, $systemCompact)
            switchRow("waveform.path.ecg", strings.systemDetailed, $systemDetailed)
            switchRow("calendar", strings.agenda, $agenda)
            switchRow("calendar.badge.clock", strings.nextEvent, $nextEvent)
            switchRow("calendar.circle", strings.monthCalendar, $calendarMonth)
            switchRow("globe", strings.worldClock, $worldClock)
            if worldClock { clockEditor }
            switchRow("keyboard", strings.accessories, $accessories)
            if accessories {
                Text(strings.accessoriesCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, settingsRowTextInset)
            }
            if usesCalendar {
                SettingsRow(symbol: "text.alignleft", title: strings.showTitles,
                            caption: strings.showTitlesCaption) {
                    Toggle(strings.showTitles, isOn: $showsTitles)
                        .labelsHidden()
                        .onChange(of: showsTitles) { _, _ in DesktopWidgetsService.shared.syncWithPreferences() }
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

    /// The cities of the world clock: remove one, or search to add up to four.
    private var clockEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(strings.cities).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(clocks, id: \.self) { identifier in
                HStack {
                    Text(TimeZone(identifier: identifier).map(DesktopWorldClock.cityName) ?? identifier)
                    Spacer()
                    Button {
                        clocks.removeAll { $0 == identifier }
                        saveClocks()
                    } label: {
                        Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .font(.callout)
            }
            if clocks.count < DesktopWorldClock.maxClocks {
                Text(strings.addCity).font(.caption).foregroundStyle(.secondary)
                TextField(strings.searchCity, text: $citySearch)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 260)
                ForEach(DesktopWorldClock.search(citySearch, excluding: clocks), id: \.self) { identifier in
                    Button {
                        clocks.append(identifier)
                        citySearch = ""
                        saveClocks()
                    } label: {
                        Label(TimeZone(identifier: identifier).map(DesktopWorldClock.cityName) ?? identifier,
                              systemImage: "plus.circle")
                    }
                    .buttonStyle(.plain)
                    .font(.callout)
                }
            }
        }
        .padding(.leading, settingsRowTextInset)
    }

    private func saveClocks() {
        UserDefaults.standard.set(clocks, forKey: DefaultsKey.desktopWidgetClocks)
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
