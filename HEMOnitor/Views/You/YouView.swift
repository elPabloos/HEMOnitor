//
//  YouView.swift
//  HEMOnitor
//

import SwiftUI

/// The "You" tab: patient profile, display preferences, the timeline entry point,
/// calibration, and account-level reset.
///
/// Not wired into `AppShellView` by this task — see the task file's
/// "Integration notes" for what the parent needs to do. `onOpenTimeline` and
/// `onCalibrate` are handed in as closures rather than owned here, matching how
/// the existing card views (`QuickActionsCard`) take navigation callbacks instead
/// of presenting destinations themselves.
struct YouView: View {
    @ObservedObject var viewModel: FactorTrackerViewModel
    let onOpenTimeline: () -> Void
    let onCalibrate: () -> Void

    @State private var showingEditSheet = false
    @State private var showingResetAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.stackGapLarge) {
                Text("You")
                    .font(AppTextStyle.screenTitle)
                    .foregroundStyle(AppColor.ink)
                    .padding(.top, Theme.Spacing.stackGap)

                ProfileRowsCard(
                    model: viewModel.model,
                    productName: viewModel.productName,
                    onEdit: { showingEditSheet = true }
                )

                displayStyleCard

                TimelineNavCard(onTap: onOpenTimeline)

                CalibrationCTACard(
                    isCalibrated: viewModel.model.calibrationFactor != nil,
                    onTap: onCalibrate
                )

                resetSection
            }
            .padding(.horizontal, Theme.Spacing.screenGutter)
            .padding(.top, Theme.Spacing.screenGutter)
            .padding(.bottom, Theme.Spacing.stackGapLarge)
        }
        .sheet(isPresented: $showingEditSheet) {
            ProfileEditSheet(viewModel: viewModel)
        }
    }

    // MARK: - Display style

    private var displayStyleCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.stackGapSmall) {
            Text("Level display")
                .font(AppTextStyle.headline)
                .foregroundStyle(AppColor.ink)

            Picker("Level display", selection: $viewModel.displayStyle) {
                Text("Ring").tag(DisplayStyle.ring)
                Text("Number").tag(DisplayStyle.numeral)
                Text("Curve").tag(DisplayStyle.curve)
            }
            .pickerStyle(.segmented)
        }
        .glassCard()
    }

    // MARK: - Reset

    private var resetSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.stackGapSmall) {
            Button(role: .destructive) {
                showingResetAlert = true
            } label: {
                Text("Reset level & history")
                    .font(.jakarta(15, weight: .bold))
                    .foregroundStyle(AppColor.dangerForeground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background {
                        Capsule()
                            .fill(AppColor.dangerBackground)
                            .overlay(Capsule().strokeBorder(AppColor.dangerForeground, lineWidth: 1))
                    }
            }
            .buttonStyle(.plain)
            .alert("Reset level and history?", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    viewModel.resetAll()
                }
            } message: {
                Text("This clears every recorded injection and returns the estimate to baseline. Your calibration stays in place.")
            }

            Text("Resetting clears your injection history and returns the estimated level to baseline. It does not undo any calibration you've set.")
                .font(AppTextStyle.caption)
                .foregroundStyle(AppColor.inkTertiary)
        }
    }
}

#Preview {
    YouView(
        viewModel: FactorTrackerViewModel(settings: .defaultSettings),
        onOpenTimeline: {},
        onCalibrate: {}
    )
    .background(AppColor.backgroundGradient)
}
