// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Syntex Utils: unofficial personal fork of Vorssaint, under the same license.

import Foundation

/// What changes when this code runs as Syntex Utils (`./build.sh --syntex`).
///
/// The fork is told apart by its bundle identifier, as the Developer build is
/// by its `.dev` suffix, so the same sources build the official app, the
/// Developer app and the fork without a compile flag. Everything here is
/// inert in the other two.
///
/// TRADEMARKS.md asks a fork for its own update feed. Syntex Utils has none:
/// it must never download the official release over itself, and it must not
/// send feedback or share links through the official project's servers.
enum SyntexFork {
    static let bundleIdentifier = "com.syntropylabs.syntex.utils"

    static func isFork(bundleIdentifier: String?) -> Bool {
        bundleIdentifier == Self.bundleIdentifier
    }

    static var isRunning: Bool {
        isFork(bundleIdentifier: Bundle.main.bundleIdentifier)
    }

    /// Features the fork leaves uninstalled. Fan control talks to a helper
    /// that only accepts the official team's signature (FanControlXPC), so a
    /// fork signed by another team could install it but never drive the fans.
    static let featuresLeftUninstalled: Set<AppFeature> = [.fanControl]

    /// The fork installs every other feature. The two owners of this fork
    /// ran the official app (everything installed) and the Developer one
    /// (widgets) side by side; one app has to cover both. The hardware gate
    /// still applies: FeatureRuntime hides what this Mac cannot run.
    static func availabilityDefaults() -> [String: Any] {
        Dictionary(uniqueKeysWithValues: AppFeature.allCases.map {
            ($0.availabilityKey, !featuresLeftUninstalled.contains($0))
        })
    }

    /// Switches that would send data to the official project's servers.
    /// Forced off at every launch, so a restored backup or an old domain
    /// copied by the migration cannot turn them back on.
    static let serverSwitches = [
        DefaultsKey.recorderSharingEnabled,
        DefaultsKey.screenshotSharingEnabled,
    ]

    /// Applied by `Defaults.register()`, after the upstream registrations,
    /// so the fork's values win. Does nothing outside the fork.
    static func applyLaunchPolicy(to defaults: UserDefaults, isFork: Bool) {
        guard isFork else { return }
        defaults.register(defaults: availabilityDefaults())
        turnOffServerSwitches(in: defaults)
    }

    static func turnOffServerSwitches(in defaults: UserDefaults) {
        for key in serverSwitches {
            defaults.set(false, forKey: key)
        }
    }

    /// Whether a feature that reaches the official servers may run here.
    /// The services check it right before the request, so nothing reaches
    /// the network even if a switch was turned on during this session.
    static func allowsOfficialServers(bundleIdentifier: String?) -> Bool {
        !isFork(bundleIdentifier: bundleIdentifier)
    }

    static var allowsOfficialServers: Bool {
        allowsOfficialServers(bundleIdentifier: Bundle.main.bundleIdentifier)
    }

    /// Whether the official project's invitations may show: Buy Me a Coffee,
    /// a star on its GitHub repository, its Discord. With the app's name
    /// rewritten they read as a plea for Syntex Utils while every link
    /// leads to Vorssaint, and the fork's owner asked for them gone. The
    /// About page's link to the original repository stays: that is credit.
    static func showsUpstreamInvitations(bundleIdentifier: String?) -> Bool {
        !isFork(bundleIdentifier: bundleIdentifier)
    }

    static var showsUpstreamInvitations: Bool {
        showsUpstreamInvitations(bundleIdentifier: Bundle.main.bundleIdentifier)
    }

    /// Credit shown in About. It names the original project on purpose:
    /// build.sh rewrites the app name in visible texts, and this file is
    /// left out of that rewrite.
    static func attribution(_ language: AppLanguage) -> String {
        switch language {
        case .enUS: return "Unofficial fork of Vorssaint, under GPL-3.0"
        case .ptBR: return "Fork não oficial do Vorssaint, sob GPL-3.0"
        case .es: return "Fork no oficial de Vorssaint, bajo GPL-3.0"
        case .sk: return "Neoficiálny fork aplikácie Vorssaint, pod licenciou GPL-3.0"
        case .de: return "Inoffizieller Fork von Vorssaint, unter GPL-3.0"
        case .fr: return "Fork non officiel de Vorssaint, sous GPL-3.0"
        case .it: return "Fork non ufficiale di Vorssaint, sotto GPL-3.0"
        case .ja: return "Vorssaint の非公式フォーク（GPL-3.0）"
        case .ko: return "Vorssaint의 비공식 포크, GPL-3.0"
        case .zhHans: return "Vorssaint 的非官方分支，采用 GPL-3.0"
        case .tr: return "Vorssaint’in resmi olmayan çatalı, GPL-3.0 altında"
        case .ru: return "Неофициальный форк Vorssaint, под лицензией GPL-3.0"
        case .uk: return "Неофіційний форк Vorssaint, за ліцензією GPL-3.0"
        case .zhTW: return "Vorssaint 的非官方分支，採用 GPL-3.0"
        case .zhHK: return "Vorssaint 的非官方分支，採用 GPL-3.0"
        }
    }
}
