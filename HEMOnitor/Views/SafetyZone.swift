//
//  SafetyZone.swift
//  HEMOnitor
//

import SwiftUI

/// Safety zone computed from a DISPLAY percentage (not real), used only for
/// color-coding cards. Not a clinical recommendation — the thresholds are
/// informational, meant to make the level easy to scan at a glance.
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
        case .critical: return AppColor.zoneCritical
        case .severe: return AppColor.zoneLow
        case .moderate: return AppColor.zonePartial
        case .safe: return AppColor.zoneWellCovered
        case .high: return AppColor.zoneAboveNormal
        }
    }

    var label: String {
        switch self {
        case .critical: return "Critical"
        case .severe: return "Severe"
        case .moderate: return "Moderate"
        case .safe: return "Safe"
        case .high: return "High"
        }
    }
}
