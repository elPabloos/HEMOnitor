//
//  SafetyZone.swift
//  HEMOnitor
//

import SwiftUI

/// Zonă de siguranță calculată dintr-un procent AFIȘAT (nu real), folosită doar
/// pentru codarea vizuală prin culoare a cardurilor. Nu reprezintă o recomandare
/// clinică — pragurile sunt informative, pentru a face nivelul ușor de scanat.
enum SafetyZone {
    case critical
    case severe
    case moderate
    case safe
    case high

    init(displayPercent: Double) {
        switch displayPercent {
        case ..<1:
            self = .critical
        case 1..<5:
            self = .severe
        case 5..<40:
            self = .moderate
        case 40...100:
            self = .safe
        default:
            self = .high
        }
    }

    var color: Color {
        switch self {
        case .critical: return .red
        case .severe: return .orange
        case .moderate: return .yellow
        case .safe: return .green
        case .high: return .blue
        }
    }

    var label: String {
        switch self {
        case .critical: return "Critic"
        case .severe: return "Sever"
        case .moderate: return "Moderat"
        case .safe: return "Sigur"
        case .high: return "Ridicat"
        }
    }
}
