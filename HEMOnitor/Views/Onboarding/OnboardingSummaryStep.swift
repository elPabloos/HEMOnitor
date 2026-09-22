//
//  OnboardingSummaryStep.swift
//  HEMOnitor
//

import SwiftUI

/// Onboarding step 3: a read-only recap of the choices made in steps 1–2,
/// plus the standing disclaimer that HEMOnitor is a tracking aid, not a
/// dosing tool.
struct OnboardingSummaryStep: View {
    let weightKg: Int
    let baselineTier: BaselineTier
    let product: OnboardingProduct

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.stackGapLarge) {
            VStack(alignment: .leading, spacing: Theme.Spacing.stackGap) {
                Text("Your setup")
                    .font(AppTextStyle.headline)
                    .foregroundStyle(AppColor.ink)

                VStack(spacing: 0) {
                    summaryRow(label: "Weight", value: "\(weightKg) kg")
                    divider
                    summaryRow(label: "Baseline", value: "\(baselineTier.displayRange) (\(baselineTier.label))")
                    divider
                    summaryRow(label: "Product", value: product.name)
                    divider
                    summaryRow(label: "Half-life", value: "\(Int(product.halfLifeHours))h")
                }
            }
            .glassCard()

            Text("HEMOnitor estimates your factor level from doses and half-life decay. It is a tracking aid, not a dosing tool — always follow your care team's guidance for treatment decisions.")
                .font(AppTextStyle.caption)
                .foregroundStyle(AppColor.inkSecondary)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(AppColor.ink.opacity(0.08))
            .frame(height: 1)
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(AppTextStyle.body)
                .foregroundStyle(AppColor.inkSecondary)
            Spacer()
            Text(value)
                .font(.plexMono(15, weight: .bold))
                .foregroundStyle(AppColor.ink)
        }
        .padding(.vertical, Theme.Spacing.stackGapSmall)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ZStack {
        AppColor.backgroundGradient.ignoresSafeArea()
        OnboardingSummaryStep(
            weightKg: 65,
            baselineTier: .moderate,
            product: OnboardingProduct.catalogue[0]
        )
        .padding(Theme.Spacing.screenGutter)
    }
}
