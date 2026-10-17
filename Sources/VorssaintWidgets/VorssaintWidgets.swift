// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI
import WidgetKit

@main
struct VorssaintWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SystemWidget()
        CalendarWidget()
    }
}
