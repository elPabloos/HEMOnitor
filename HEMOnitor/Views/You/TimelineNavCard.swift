//
//  TimelineNavCard.swift
//  HEMOnitor
//

import SwiftUI

/// A tappable card that hands off to the timeline screen. `YouView` doesn't build
/// that screen itself — it just exposes the entry point via `onTap`.
struct TimelineNavCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.Spacing.stackGap) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Timeline")
                        .font(AppTextStyle.headline)
                        .foregroundStyle(AppColor.ink)
                    Text("Estimated level over time & injection history")
                        .font(AppTextStyle.body)
                        .foregroundStyle(AppColor.inkSecondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColor.inkTertiary)
            }
        }
        .buttonStyle(.plain)
        .glassCard()
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the timeline screen")
    }
}

#Preview {
    TimelineNavCard(onTap: {})
        .padding()
        .background(AppColor.backgroundGradient)
}
