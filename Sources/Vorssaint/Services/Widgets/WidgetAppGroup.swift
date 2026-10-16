// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The App Group container the app and the widget extension share.
///
/// `build.sh --widgets` writes the group into both Info.plists and both
/// entitlements, prefixed with the signing certificate's team ID (macOS
/// accepts a team-prefixed group without a provisioning profile; a
/// `group.` one would need a profile). A build without widgets has no key,
/// so the app never touches a container it is not entitled to: on recent
/// macOS that would raise a "wants to access data from other apps" prompt.
enum WidgetAppGroup {
    static let infoKey = "VorssaintAppGroup"
    /// A folder of our own inside the container, so tightening permissions
    /// never touches the container root that macOS manages.
    static let folderName = "Widgets"

    static var identifier: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: infoKey) as? String,
              !value.isEmpty
        else { return nil }
        return value
    }

    static var snapshotFolder: URL? {
        guard let identifier,
              let container = FileManager.default.containerURL(
                  forSecurityApplicationGroupIdentifier: identifier)
        else { return nil }
        return container.appendingPathComponent(folderName, isDirectory: true)
    }
}
