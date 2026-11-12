// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Syntex Utils: unofficial personal fork of Vorssaint, under the same license.

import Foundation

/// What these tests protect: Syntex Utils never replaces itself with the
/// official release, never talks to the official project's servers, and
/// installs every feature but the one it cannot run; and none of that leaks
/// into the official app or the Developer build, which share these sources.
enum SyntexForkTests {
    static func run(_ suite: TestSuite) {
        identity(suite)
        availability(suite)
        serverSwitches(suite)
        invitations(suite)
        wiring(suite)
    }

    /// The official project's invitations (donate, star the repository,
    /// Discord) would ask for support on its behalf from inside the fork.
    private static func invitations(_ suite: TestSuite) {
        suite.expect(!SyntexFork.showsUpstreamInvitations(bundleIdentifier: SyntexFork.bundleIdentifier),
                     "the fork shows none of the official project's invitations")
        suite.expect(SyntexFork.showsUpstreamInvitations(bundleIdentifier: "com.vorssaint.utils")
                        && SyntexFork.showsUpstreamInvitations(bundleIdentifier: "com.vorssaint.utils.dev")
                        && SyntexFork.showsUpstreamInvitations(bundleIdentifier: nil),
                     "the official and Developer builds keep them")
        let everything: (AppFeature) -> Bool = { _ in true }
        suite.expect(!FeatureVisibilitySupport.isPageVisible(.support, isAvailable: everything,
                                                             showsInvitations: false),
                     "the Support page leaves Settings, its search and its sidebar in the fork")
        suite.expect(FeatureVisibilitySupport.isPageVisible(.support, isAvailable: everything,
                                                            showsInvitations: true),
                     "the Support page stays in the official app")
        suite.expect([SettingsPage.about, .general, .releaseNotes].allSatisfy {
                        FeatureVisibilitySupport.isPageVisible($0, isAvailable: everything, showsInvitations: false)
                     },
                     "hiding Support hides no other page")
    }

    private static func identity(_ suite: TestSuite) {
        suite.expect(SyntexFork.isFork(bundleIdentifier: "com.syntropylabs.syntex.utils"),
                     "the fork is recognised by its bundle id")
        for other in ["com.vorssaint.utils", "com.vorssaint.utils.dev", "com.syntropylabs.syntex.utils.dev",
                      "com.syntropylabs.syntex", ""] {
            suite.expect(!SyntexFork.isFork(bundleIdentifier: other),
                         "\(other.isEmpty ? "an empty id" : other) is not the fork")
        }
        suite.expect(!SyntexFork.isFork(bundleIdentifier: nil), "a bare binary (no bundle id) is not the fork")
        suite.expect(!SyntexFork.allowsOfficialServers(bundleIdentifier: SyntexFork.bundleIdentifier),
                     "the fork may not reach the official servers")
        suite.expect(SyntexFork.allowsOfficialServers(bundleIdentifier: "com.vorssaint.utils")
                        && SyntexFork.allowsOfficialServers(bundleIdentifier: "com.vorssaint.utils.dev")
                        && SyntexFork.allowsOfficialServers(bundleIdentifier: nil),
                     "the official and Developer builds keep their servers")
    }

    private static func availability(_ suite: TestSuite) {
        let defaults = SyntexFork.availabilityDefaults()
        suite.expect(defaults.count == AppFeature.allCases.count,
                     "the fork decides every feature: \(defaults.count) of \(AppFeature.allCases.count)")
        let uninstalled = AppFeature.allCases.filter { (defaults[$0.availabilityKey] as? Bool) != true }
        suite.expect(uninstalled == [.fanControl],
                     "every feature but fan control is installed in the fork, uninstalled: \(uninstalled)")
        let optIn = AppFeature.allCases.filter { !$0.installedByDefault && $0 != .fanControl }
        suite.expect(!optIn.isEmpty && optIn.allSatisfy { (defaults[$0.availabilityKey] as? Bool) == true },
                     "the official opt-in features start installed in the fork")
        suite.expect(AppFeature.allCases.allSatisfy {
                        AppFeature.availabilityDefaults[$0.availabilityKey] as? Bool == $0.installedByDefault
                     },
                     "the official defaults are untouched")
    }

    private static func serverSwitches(_ suite: TestSuite) {
        let name = "com.syntropylabs.syntex.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: name) else {
            suite.expect(false, "a scratch defaults domain opens")
            return
        }
        defer { defaults.removePersistentDomain(forName: name) }
        for key in SyntexFork.serverSwitches { defaults.set(true, forKey: key) }

        SyntexFork.applyLaunchPolicy(to: defaults, isFork: false)
        suite.expect(SyntexFork.serverSwitches.allSatisfy { defaults.object(forKey: $0) as? Bool == true },
                     "outside the fork the launch policy changes nothing")

        SyntexFork.turnOffServerSwitches(in: defaults)
        suite.expect(SyntexFork.serverSwitches.allSatisfy { defaults.object(forKey: $0) as? Bool == false },
                     "the fork turns sharing off even when a copied domain had it on")
        suite.expect(Set(SyntexFork.serverSwitches)
                        == [DefaultsKey.recorderSharingEnabled, DefaultsKey.screenshotSharingEnabled],
                     "both temporary-link switches are covered")
    }

    /// The guards live in services that need AppKit and the network, so they
    /// are checked where they are written: one guard removed is one request
    /// to the official servers, or one official update over the fork.
    private static func wiring(_ suite: TestSuite) {
        func source(_ path: String) -> String {
            (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        }
        func body(_ text: String, after marker: String, lines: Int) -> String {
            guard let start = text.range(of: marker) else { return "" }
            return text[start.lowerBound...].split(separator: "\n", omittingEmptySubsequences: false)
                .prefix(lines).joined(separator: "\n")
        }
        let update = source("Sources/Vorssaint/Services/Update/UpdateService.swift")
        suite.expect(body(update, after: "    func startAutomaticChecks() {", lines: 6)
                        .contains("if SyntexFork.isRunning { return }"),
                     "the fork never schedules update checks")
        suite.expect(body(update, after: "    func check(manual: Bool) {", lines: 3)
                        .contains("if SyntexFork.isRunning {"),
                     "a manual check in the fork never reaches the official feed")
        suite.expect(body(update, after: "    func checkIfStale(", lines: 3).contains("SyntexFork.isRunning"),
                     "reactivating the fork never checks the official feed")
        suite.expect(body(update, after: "    func downloadAndInstall() {", lines: 4)
                        .contains("if SyntexFork.isRunning { return }"),
                     "the fork never installs the official release over itself")

        let feedback = source("Sources/Vorssaint/Services/Feedback/FeedbackService.swift")
        suite.expect(body(feedback, after: "    func submit(kind: FeedbackKind,", lines: 6)
                        .contains("guard SyntexFork.allowsOfficialServers else { throw FeedbackError.unavailable }"),
                     "feedback from the fork never reaches the official maintainers")
        for (path, marker) in [("Sources/Vorssaint/Services/Recorder/RecordingShareService.swift",
                                "    func createLink(artifact:"),
                               ("Sources/Vorssaint/Services/QuickTools/ScreenshotShareService.swift",
                                "    func createLink(pngData:")] {
            suite.expect(body(source(path), after: marker, lines: 5).contains("guard SyntexFork.allowsOfficialServers,"),
                         "\((path as NSString).lastPathComponent) uploads nothing from the fork")
        }

        let delegate = source("Sources/Vorssaint/App/AppDelegate.swift")
        suite.expect(body(delegate, after: "    private func showSupportUpdateIntroIfNeeded() -> Bool {", lines: 2)
                        .contains("guard SyntexFork.showsUpstreamInvitations else { return false }"),
                     "the fork never queues the after-update invitation, so the next intro runs")
        suite.expect(body(delegate, after: "    private func showSupportUpdateIntro(isReview: Bool = false) {", lines: 2)
                        .contains("guard SyntexFork.showsUpstreamInvitations else { return }"),
                     "reviewing the tour in the fork does not end on the invitation")
        let showcase = source("Sources/Vorssaint/UI/Onboarding/WhatsNewView.swift")
        suite.expect(body(showcase, after: "    private var showcaseStep: some View {", lines: 80)
                        .contains("if SyntexFork.showsUpstreamInvitations {"),
                     "the feature showcase in the fork closes instead of turning to the support step")

        let registration = source("Sources/Vorssaint/Core/Defaults.swift")
        let upstream = registration.range(of: "defaults.register(defaults: AppFeature.availabilityDefaults)")
        let fork = registration.range(of: "SyntexFork.applyLaunchPolicy(to: defaults,")
        suite.expect(upstream != nil && fork != nil && upstream!.upperBound < fork!.lowerBound,
                     "the fork's availability is registered after the official one, so it wins")
    }
}
