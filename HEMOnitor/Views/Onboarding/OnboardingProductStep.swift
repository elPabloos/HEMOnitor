//
//  OnboardingProductStep.swift
//  HEMOnitor
//

import SwiftUI

/// Onboarding step 2: a vertical list of selectable factor VIII products,
/// each showing its half-life so the choice's consequence is visible upfront.
struct OnboardingProductStep: View {
    @Binding var selectedProductID: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.stackGap) {
            ForEach(OnboardingProduct.catalogue) { product in
                productCard(product)
            }

            Text("Half-life is a starting estimate. Calibrating from a lab result later will personalize it to you.")
                .font(AppTextStyle.caption)
                .foregroundStyle(AppColor.inkSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Theme.Spacing.stackGapSmall)
        }
    }

    private func productCard(_ product: OnboardingProduct) -> some View {
        let isSelected = product.id == selectedProductID
        return Button {
            selectedProductID = product.id
        } label: {
            HStack(spacing: Theme.Spacing.stackGap) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(product.name)
                        .font(.jakarta(17, weight: .bold))
                        .foregroundStyle(AppColor.ink)
                    Text(product.subtitle)
                        .font(AppTextStyle.caption)
                        .foregroundStyle(AppColor.inkSecondary)
                }

                Spacer()

                Text("\(product.halfLifeHours.wholeNumberText)h")
                    .font(.plexMono(16, weight: .bold))
                    .foregroundStyle(AppColor.primaryGreen)
            }
            .padding(Theme.Spacing.cardPaddingCompact)
            .background {
                let shape = RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                shape
                    .fill(AppColor.glassFill)
                    .background(.ultraThinMaterial, in: shape)
                    .overlay {
                        shape.strokeBorder(isSelected ? AppColor.primaryGreen : AppColor.glassBorder, lineWidth: isSelected ? 2 : 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(product.name), \(product.subtitle), half-life \(Int(product.halfLifeHours)) hours")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    ZStack {
        AppColor.backgroundGradient.ignoresSafeArea()
        ScrollView {
            OnboardingProductStep(selectedProductID: .constant("elocta"))
                .padding(Theme.Spacing.screenGutter)
        }
    }
}
