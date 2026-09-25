//
//  StatTile.swift
//  HEMOnitor
//

import SwiftUI

/// One of the two compact stat tiles on Home ("Last dose", "Days of cover").
struct StatTile: View {
    let title: String
    let value: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppTextStyle.caption)
                .foregroundStyle(AppColor.inkSecondary)
            Text(value)
                .font(.plexMono(20, weight: .bold))
                .foregroundStyle(AppColor.ink)
            if let subtitle {
                Text(subtitle)
                    .font(AppTextStyle.caption)
                    .foregroundStyle(AppColor.inkTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: HomeRadius.card, padding: Theme.Spacing.cardPaddingCompact)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HStack(spacing: 10) {
        StatTile(title: "Last dose", value: "2000 IU", subtitle: "3h ago")
        StatTile(title: "Days of cover", value: "12 days", subtitle: nil)
    }
    .padding()
    .background(AppColor.backgroundGradient)
}
