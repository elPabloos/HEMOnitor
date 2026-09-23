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

    /// At accessibility sizes the dot/label/note row can't stay on one line — it used
    /// to overflow the capsule and hyphenate mid-word ("protecti / ve"). The note
    /// moves below the label instead.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    labelRow
                    noteText
                }
            } else {
                HStack(spacing: 8) {
                    labelRow
                    Text("·")
                        .foregroundStyle(AppColor.inkTertiary)
                    noteText
                }
            }
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

    private var labelRow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(zone.color)
                .frame(width: 8, height: 8)
            Text(zone.label)
                .font(AppTextStyle.bodyEmphasis)
                .foregroundStyle(zone.color)
        }
    }

    private var noteText: some View {
        Text(note)
            .font(AppTextStyle.caption)
            .foregroundStyle(AppColor.inkSecondary)
            // Wrap between words rather than letting the capsule clip mid-word.
            .fixedSize(horizontal: false, vertical: true)
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
