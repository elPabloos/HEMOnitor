//
//  NoStockPromptCard.swift
//  HEMOnitor
//

import SwiftUI

/// Amber warning card shown when there is no stock on record, nudging the
/// user toward the Stock tab. `HomeView` decides visibility from a `hasStock`
/// parameter handed down by the parent — this view never reads stock state
/// itself.
struct NoStockPromptCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppColor.warningForeground)
                    .font(.system(size: 18, weight: .semibold))

                VStack(alignment: .leading, spacing: 2) {
                    Text("No stock on record")
                        .font(AppTextStyle.bodyEmphasis)
                        .foregroundStyle(AppColor.warningForeground)
                    Text("Add a delivery to log injections in one tap")
                        .font(AppTextStyle.caption)
                        .foregroundStyle(AppColor.warningForeground.opacity(0.85))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColor.warningForeground.opacity(0.6))
            }
            .padding(Theme.Spacing.cardPadding)
            .background {
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(AppColor.warningBackground)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the Stock tab to add a delivery")
    }
}

#Preview {
    NoStockPromptCard(onTap: {})
        .padding()
        .background(AppColor.backgroundGradient)
}
