//
//  OnboardingWeightBaselineStep.swift
//  HEMOnitor
//

import SwiftUI

/// Onboarding step 1: body weight (a stepper) and baseline factor level (a
/// three-tier severity picker), both required to seed the PK model.
struct OnboardingWeightBaselineStep: View {
    @Binding var weightKg: Int
    @Binding var baselineTier: BaselineTier

    private let weightRange = 20...200

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.stackGapLarge) {
            weightSection

            Rectangle()
                .fill(AppColor.ink.opacity(0.08))
                .frame(height: 1)

            baselineSection
        }
        .glassCard()
    }

    private var weightSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.stackGap) {
            Text("Body weight")
                .font(AppTextStyle.bodyEmphasis)
                .foregroundStyle(AppColor.ink)

            HStack {
                stepperButton(systemImage: "minus", label: "Decrease weight") {
                    weightKg = max(weightRange.lowerBound, weightKg - 1)
                }

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(weightKg)")
                        .font(.jakarta(40, weight: .extraBold))
                        .foregroundStyle(AppColor.ink)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.12), value: weightKg)
                    Text("kg")
                        .font(AppTextStyle.body)
                        .foregroundStyle(AppColor.inkSecondary)
                }

                Spacer()

                stepperButton(systemImage: "plus", label: "Increase weight") {
                    weightKg = min(weightRange.upperBound, weightKg + 1)
                }
            }
        }
    }

    private func stepperButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppColor.primaryGreen)
                .frame(width: 44, height: 44)
                .background(Circle().fill(AppColor.primaryGreen.opacity(0.12)))
        }
        .accessibilityLabel(label)
    }

    private var baselineSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.stackGap) {
            Text("Baseline factor level")
                .font(AppTextStyle.bodyEmphasis)
                .foregroundStyle(AppColor.ink)

            HStack(spacing: Theme.Spacing.stackGapSmall) {
                ForEach(BaselineTier.allCases) { tier in
                    baselineButton(tier)
                }
            }
        }
    }

    private func baselineButton(_ tier: BaselineTier) -> some View {
        let isSelected = tier == baselineTier
        return Button {
            baselineTier = tier
        } label: {
            VStack(spacing: 4) {
                Text(tier.displayRange)
                    .font(.plexMono(17, weight: .bold))
                Text(tier.label)
                    .font(AppTextStyle.caption)
            }
            .foregroundStyle(isSelected ? .white : AppColor.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: Theme.Radius.input, style: .continuous)
                    .fill(isSelected ? AppColor.primaryGreen : AppColor.ink.opacity(0.05))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(tier.label), \(tier.displayRange)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    ZStack {
        AppColor.backgroundGradient.ignoresSafeArea()
        OnboardingWeightBaselineStep(
            weightKg: .constant(65),
            baselineTier: .constant(.moderate)
        )
        .padding(Theme.Spacing.screenGutter)
    }
}
