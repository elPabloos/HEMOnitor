//
//  AppTab.swift
//  HEMOnitor
//

import Foundation

/// The four destinations in the bottom bar. Logging a dose is deliberately *not*
/// one of them — it's a separate floating button, matching the design.
enum AppTab: String, CaseIterable, Identifiable {
    case home
    case stock
    case alerts
    case you

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .stock: return "Stock"
        case .alerts: return "Alerts"
        case .you: return "You"
        }
    }

    /// Spoken by VoiceOver in place of the visual dot-and-label treatment.
    var accessibilityLabel: String {
        switch self {
        case .home: return "Home, estimated factor level"
        case .stock: return "Stock, vials on hand"
        case .alerts: return "Alerts, level notifications"
        case .you: return "You, profile and settings"
        }
    }
}
