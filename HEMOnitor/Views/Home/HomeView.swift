//
//  HomeView.swift
//  HEMOnitor
//
//  Created by Ciudin, Paul-Catalin on 05.08.2025.
//

import SwiftUI

/// The Home tab: the current estimated level (in one of three user-chosen
/// styles), a cover-window projection, a stock nudge, quick stats and recent
/// activity. Deliberately has no `NavigationStack`/`navigationTitle` — the
/// custom header below replaces it so `AppShellView`'s background gradient
/// shows through (see task 014).
struct HomeView: View {
    /// Owned by `HEMOnitorApp` and passed down through `AppShellView` — observed
    /// here, not owned, so switching tabs away and back doesn't disturb it.
    @ObservedObject var viewModel: FactorTrackerViewModel

    /// Whether there is stock on record. Home does not read `AppRepository`
    /// itself — the parent (which owns the Stock domain) hands this down, so
    /// the no-stock prompt can be shown/hidden without Home depending on Stock.
    var hasStock: Bool = false

    /// Pre-formatted "days of cover" text for the stat tile, or nil to show a
    /// placeholder. Owned by the parent for the same reason as `hasStock`.
    var coverDaysText: String? = nil

    /// Called when the no-stock prompt is tapped (expected to switch to the
    /// Stock tab).
    var onAddDelivery: () -> Void = {}

    @State private var showingCalibration = false

    /// The "Look ahead" slider on the cover-window card, forward-only (0...72h).
    @State private var lookAheadHours: Double = 0

    @State private var showResetRealAlert = false

    // Timer: refreshes the level every 60 seconds.
    private let timer = Timer
        .publish(every: 60, on: .main, in: .common)
        .autoconnect()

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.stackGapLarge) {
                HomeHeaderView(
                    isCalibrated: viewModel.model.calibrationFactor != nil,
                    onCalibrate: { showingCalibration = true }
                )

                VStack(spacing: Theme.Spacing.stackGap) {
                    LevelVisualization(
                        displayPercent: viewModel.currentDisplayLevelPercent,
                        zone: zone,
                        style: viewModel.displayStyle,
                        curvePoints: curvePoints,
                        onStyleChange: { viewModel.displayStyle = $0 }
                    )
                    ZoneBadge(zone: zone)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.stackGap)

                CoverWindowCard(
                    model: viewModel.model,
                    currentRealPercent: viewModel.currentRealLevelPercent,
                    lookAheadHours: $lookAheadHours
                )

                if !hasStock {
                    NoStockPromptCard(onTap: onAddDelivery)
                }

                HStack(spacing: Theme.Spacing.stackGap) {
                    StatTile(
                        title: "Last dose",
                        value: lastDoseValue,
                        subtitle: lastDoseSubtitle
                    )
                    StatTile(
                        title: "Days of cover",
                        value: coverDaysText ?? "—",
                        subtitle: coverDaysText == nil ? "Not tracked yet" : nil
                    )
                }

                RecentActivityCard(injections: viewModel.injections, model: viewModel.model)

                resetButton

                footnote
            }
            .padding(.horizontal, Theme.Spacing.screenGutter)
            .padding(.top, Theme.Spacing.stackGap)
            .padding(.bottom, Theme.Spacing.stackGapLarge)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            viewModel.recalculateLevels()
        }
        .onReceive(timer) { date in
            viewModel.recalculateLevels(at: date)
        }
        .sheet(isPresented: $showingCalibration) {
            CalibrationView(viewModel: viewModel)
        }
    }

    // MARK: - Derived display state

    private var zone: SafetyZone {
        SafetyZone(displayPercent: viewModel.currentDisplayLevelPercent)
    }

    private var curvePoints: [DecayCurvePoint] {
        DecayCurve.sample(model: viewModel.model, currentRealPercent: viewModel.currentRealLevelPercent)
    }

    private var lastDoseValue: String {
        guard let last = viewModel.injections.last else { return "—" }
        return "\(Int(last.doseIU)) IU"
    }

    private var lastDoseSubtitle: String? {
        guard let last = viewModel.injections.last else { return "No doses yet" }
        return relativeText(since: last.date)
    }

    private func relativeText(since date: Date) -> String {
        let hours = Date().timeIntervalSince(date) / 3600
        if hours < 1 { return "\(max(0, Int(hours * 60)))min ago" }
        if hours < 48 { return String(format: "%.1fh ago", hours) }
        return String(format: "%.1fd ago", hours / 24)
    }

    // MARK: - Reset (restyled, same confirmation flow as before)

    private var resetButton: some View {
        Button(role: .destructive) {
            showResetRealAlert = true
        } label: {
            Text("Reset history")
                .font(AppTextStyle.bodyEmphasis)
                .foregroundStyle(AppColor.dangerForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .alert(
            "Clear history and reset the level?",
            isPresented: $showResetRealAlert
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                viewModel.resetAll()
                lookAheadHours = 0
            }
        } message: {
            Text("This will delete all injections and return the level to baseline.")
        }
    }

    private var footnote: some View {
        Text("Estimates only, based on doses and half-life decay. Zones are informational and not medical advice.")
            .font(AppTextStyle.caption)
            .foregroundStyle(AppColor.inkTertiary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, Theme.Spacing.stackGap)
    }
}

#Preview("No stock") {
    ZStack {
        AppColor.backgroundGradient.ignoresSafeArea()
        HomeView(viewModel: FactorTrackerViewModel())
    }
}

#Preview("With stock + cover days") {
    ZStack {
        AppColor.backgroundGradient.ignoresSafeArea()
        HomeView(viewModel: FactorTrackerViewModel(), hasStock: true, coverDaysText: "12 days")
    }
}
