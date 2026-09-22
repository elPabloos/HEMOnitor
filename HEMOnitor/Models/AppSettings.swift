//
//  AppSettings.swift
//  HEMOnitor
//

import Foundation

/// How the current level is displayed on the main screen.
enum DisplayStyle: String, Codable, CaseIterable {
    case ring
    case numeral
    case curve
}

/// Patient parameters and app preferences, persisted to disk.
/// Mirrors the fields on `FactorVIIIModel` plus preferences unrelated to the
/// PK calculation (onboarding, display style).
struct AppSettings: Codable, Equatable {
    var weightKg: Double
    var baselinePercent: Double
    var halfLifeHours: Double
    var productName: String
    var recoveryPercentPerIUPerKg: Double
    var calibrationFactor: Double?
    var hasCompletedOnboarding: Bool
    var displayStyle: DisplayStyle

    /// The values currently hardcoded as literals in `ContentView.init` (65kg/2%/19h, Elocta).
    static let defaultSettings = AppSettings(
        weightKg: 65,
        baselinePercent: 2,
        halfLifeHours: 19,
        productName: "Elocta",
        recoveryPercentPerIUPerKg: 2.0,
        calibrationFactor: nil,
        hasCompletedOnboarding: false,
        displayStyle: .ring
    )
}
