//
//  OnboardingView.swift
//  HEMOnitor
//

import SwiftUI

/// The three-step onboarding wizard: body weight & baseline, product & half-life,
/// then a summary that commits everything at once.
///
/// Selections live in local `@State` and are only written to `viewModel` on the
/// final step (`commitAndFinish`), via the existing `updatePatientParameters` and
/// `completeOnboarding` — this view adds no new view-model API. The caller decides
/// what "finished" means (dismiss a sheet, swap the app root, ...) via `onFinished`;
/// this view does not gate anything itself.
struct OnboardingView: View {
    @ObservedObject var viewModel: FactorTrackerViewModel
    let onFinished: () -> Void

    @State private var stepIndex: Int
    @State private var weightKg: Int
    @State private var baselineTier: BaselineTier
    @State private var selectedProductID: String

    private static let stepCount = 3

    /// `previewStepIndex` exists only so `#Preview`s can land directly on step 2/3
    /// without walking through the wizard; real call sites should omit it.
    init(viewModel: FactorTrackerViewModel, onFinished: @escaping () -> Void, previewStepIndex: Int = 0) {
        self.viewModel = viewModel
        self.onFinished = onFinished
        _stepIndex = State(initialValue: previewStepIndex)
        _weightKg = State(initialValue: Int(viewModel.model.weightKg.rounded()))
        _baselineTier = State(initialValue: .closest(to: viewModel.model.baselinePercent))
        _selectedProductID = State(initialValue: OnboardingProduct.matching(productName: viewModel.productName).id)
    }

    private var selectedProduct: OnboardingProduct {
        OnboardingProduct.catalogue.first(where: { $0.id == selectedProductID }) ?? OnboardingProduct.catalogue[0]
    }

    var body: some View {
        ZStack {
            AppColor.backgroundGradient.ignoresSafeArea()

            VStack(spacing: Theme.Spacing.stackGapLarge) {
                progressBar

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.stackGapLarge) {
                        header
                        stepContent
                    }
                }
                .scrollBounceBehavior(.basedOnSize)

                footer
            }
            .padding(.horizontal, Theme.Spacing.screenGutter)
            .padding(.top, Theme.Spacing.stackGap)
            .padding(.bottom, Theme.Spacing.stackGap)
        }
    }

    // MARK: - Chrome

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<Self.stepCount, id: \.self) { index in
                Capsule()
                    .fill(index <= stepIndex ? AppColor.primaryGreen : AppColor.ink.opacity(0.14))
                    .frame(height: 4)
            }
        }
        .animation(.easeOut(duration: 0.2), value: stepIndex)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(stepIndex + 1) of \(Self.stepCount)")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.stackGapSmall) {
            Text(kicker)
                .font(AppTextStyle.kicker)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(AppColor.inkSecondary)

            Text(title)
                .font(AppTextStyle.onboardingTitle)
                .foregroundStyle(AppColor.ink)
                .lineSpacing(-2)
                .frame(maxWidth: 300, alignment: .leading)

            Text(bodyText)
                .font(AppTextStyle.body)
                .foregroundStyle(AppColor.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        HStack(spacing: Theme.Spacing.stackGap) {
            if stepIndex > 0 {
                Button("Back") {
                    withAnimation(.easeOut(duration: 0.2)) { stepIndex -= 1 }
                }
                .buttonStyle(.secondaryPill)
            }

            Button(ctaTitle, action: advance)
                .buttonStyle(.primaryPill)
        }
    }

    // MARK: - Per-step text

    private var kicker: String {
        "Step \(stepIndex + 1) of \(Self.stepCount)"
    }

    private var title: String {
        switch stepIndex {
        case 0: return "Let's set your baseline"
        case 1: return "What product do you use?"
        default: return "You're all set"
        }
    }

    private var bodyText: String {
        switch stepIndex {
        case 0:
            return "Your weight and baseline factor level are the starting point for every level HEMOnitor predicts."
        case 1:
            return "Pick your factor VIII product so HEMOnitor uses the right half-life for decay calculations."
        default:
            return "Review your setup before you start tracking. A lab-based calibration later will refine these numbers further."
        }
    }

    private var ctaTitle: String {
        stepIndex < Self.stepCount - 1 ? "Continue" : "Start tracking"
    }

    @ViewBuilder
    private var stepContent: some View {
        switch stepIndex {
        case 0:
            OnboardingWeightBaselineStep(weightKg: $weightKg, baselineTier: $baselineTier)
        case 1:
            OnboardingProductStep(selectedProductID: $selectedProductID)
        default:
            OnboardingSummaryStep(weightKg: weightKg, baselineTier: baselineTier, product: selectedProduct)
        }
    }

    // MARK: - Actions

    private func advance() {
        if stepIndex < Self.stepCount - 1 {
            withAnimation(.easeOut(duration: 0.2)) { stepIndex += 1 }
        } else {
            commitAndFinish()
        }
    }

    /// Writes every selection through the existing view-model API, in one shot,
    /// only once the wizard is complete.
    private func commitAndFinish() {
        viewModel.updatePatientParameters(
            weightKg: Double(weightKg),
            baselinePercent: baselineTier.representativeValue,
            halfLifeHours: selectedProduct.halfLifeHours,
            productName: selectedProduct.name
        )
        viewModel.completeOnboarding()
        onFinished()
    }
}

#Preview("Step 1 — Weight & baseline") {
    OnboardingView(viewModel: FactorTrackerViewModel(settings: .defaultSettings), onFinished: {})
}

#Preview("Step 2 — Product") {
    OnboardingView(viewModel: FactorTrackerViewModel(settings: .defaultSettings), onFinished: {}, previewStepIndex: 1)
}

#Preview("Step 3 — Summary") {
    OnboardingView(viewModel: FactorTrackerViewModel(settings: .defaultSettings), onFinished: {}, previewStepIndex: 2)
}
