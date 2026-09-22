//
//  ZoneBadge.swift
//  HEMOnitor
//

import SwiftUI

/// The capsule under the level visualization: a colored dot, the zone label
/// in the zone color, and a short descriptive note. Purely informational —
/// like the rest of `SafetyZone`, not a dosing recommendation.
struct ZoneBadge: View {
    let zone: SafetyZone

    private var note: String {
        switch zone {
        case .critical: return "Below measurable protection"
        case .severe: return "Low protective coverage"
        case .moderate: return "Partial coverage"
        case .safe: return "Well covered"
        case .high: return "Above the typical range"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(zone.color)
                .frame(width: 8, height: 8)
            Text(zone.label)
                .font(AppTextStyle.bodyEmphasis)
                .foregroundStyle(zone.color)
            Text("·")
                .foregroundStyle(AppColor.inkTertiary)
            Text(note)
                .font(AppTextStyle.caption)
                .foregroundStyle(AppColor.inkSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background {
            Capsule().fill(AppColor.glassFill)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .overlay {
            Capsule().strokeBorder(AppColor.glassBorder, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(zone.label) zone, \(note)")
    }
}

#Preview {
    VStack(spacing: 12) {
        ZoneBadge(zone: .safe)
        ZoneBadge(zone: .moderate)
        ZoneBadge(zone: .critical)
    }
    .padding()
    .background(AppColor.backgroundGradient)
}
