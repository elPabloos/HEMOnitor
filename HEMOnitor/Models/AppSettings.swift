//
//  AppSettings.swift
//  HEMOnitor
//

import Foundation

/// Stilul de afișare a nivelului curent pe ecranul principal.
enum DisplayStyle: String, Codable, CaseIterable {
    case ring
    case numeral
    case curve
}

/// Parametrii pacientului și preferințele aplicației, persistate pe disc.
/// Corespunde câmpurilor de pe `FactorVIIIModel` plus preferințe care nu țin
/// de calculul PK (onboarding, stil de afișare).
struct AppSettings: Codable, Equatable {
    var weightKg: Double
    var baselinePercent: Double
    var halfLifeHours: Double
    var productName: String
    var recoveryPercentPerIUPerKg: Double
    var calibrationFactor: Double?
    var hasCompletedOnboarding: Bool
    var displayStyle: DisplayStyle

    /// Valorile folosite azi ca literali hardcodați în `ContentView.init` (65kg/2%/19h, Elocta).
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
