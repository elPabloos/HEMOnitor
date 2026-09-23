//
//  AppVersion.swift
//  HEMOnitor
//

import Foundation

/// Identifies the running build, so a tester can tell at a glance which version of
/// the app is on their phone and which task it corresponds to.
///
/// The version and build number come from the bundle (`MARKETING_VERSION` and
/// `CURRENT_PROJECT_VERSION`) rather than being written out here, so they cannot
/// drift from what was actually built.
///
/// **When merging a task to `main`:** bump `CURRENT_PROJECT_VERSION` in the Xcode
/// target and update `latestTask` below. See CLAUDE.md, "Versioning".
enum AppVersion {
    /// The most recent task merged into `main`, matching a file in `tasks/completed/`.
    static let latestTask = "022-look-ahead-slider-inert"

    static var shortVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    /// e.g. "Version 1.0 (2) · 018-timeline"
    static var displayString: String {
        "Version \(shortVersion) (\(buildNumber)) · \(latestTask)"
    }
}
