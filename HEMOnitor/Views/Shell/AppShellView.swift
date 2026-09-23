//
//  AppShellView.swift
//  HEMOnitor
//

import SwiftUI

/// The app root: onboarding until it's completed, then a tab destination plus the
/// floating bar overlay.
///
/// Navigation state lives here as plain `@State` rather than in a router object —
/// there are four destinations and a few sheets, so an observable router would add
/// indirection and a second source of truth without buying testability or decoupling.
/// Screens that need to steer navigation are handed a closure (Home's "no stock"
/// prompt jumps to the Stock tab), matching how the other views already take
/// `onCalibrate`/`onAddDelivery`-style callbacks.
///
/// This is also the only place that knows about both the factor and stock domains.
/// Neither view model references the other; the "days of cover" estimate, which needs
/// dosing history *and* stock on hand, is composed here and pushed into `StockViewModel`.
struct AppShellView: View {
    @ObservedObject var viewModel: FactorTrackerViewModel
    @ObservedObject var stockViewModel: StockViewModel
    @ObservedObject var alertsViewModel: AlertsViewModel

    @State private var selectedTab: AppTab = .home
    @State private var presentedSheet: ShellSheet?

    /// Height reserved at the bottom so scrolling content clears the floating bar.
    private let barClearance: CGFloat = 86

    /// Timeline is deliberately not one of these: it is a full-screen destination
    /// rather than a sheet, so it gets its own presentation state.
    private enum ShellSheet: String, Identifiable {
        case log, calibration, addDelivery
        var id: String { rawValue }
    }

    @State private var showingTimeline = false

    var body: some View {
        Group {
            if viewModel.hasCompletedOnboarding {
                shell
            } else {
                OnboardingView(viewModel: viewModel) {
                    // `completeOnboarding()` has already flipped and persisted the
                    // flag by the time this fires, so the Group re-evaluates itself.
                }
            }
        }
        .background(AppColor.backgroundGradient.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.25), value: viewModel.hasCompletedOnboarding)
    }

    private var shell: some View {
        ZStack(alignment: .bottom) {
            AppColor.backgroundGradient
                .ignoresSafeArea()

            content
                // Keeps the bar floating *over* scrolled content (so its translucency
                // reads) while still guaranteeing nothing ends up trapped underneath it.
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: barClearance)
                }

            bar
        }
        .onAppear {
            syncConsumptionEstimate()
            Task { await syncAlertSchedule() }
        }
        .onChange(of: viewModel.injections) { _, _ in
            syncConsumptionEstimate()
            // The predicted crossing moves with every dose logged, edited or deleted,
            // so the pending notifications have to be rebuilt alongside it.
            Task { await syncAlertSchedule() }
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .calibration:
                CalibrationView(viewModel: viewModel)
            case .log:
                LogDoseSheet(
                    viewModel: viewModel,
                    stockViewModel: stockViewModel,
                    onClose: { presentedSheet = nil }
                )
            case .addDelivery:
                AddStockSheet(
                    stockViewModel: stockViewModel,
                    defaultProductName: viewModel.productName,
                    onClose: { presentedSheet = nil }
                )
            }
        }
        .fullScreenCover(isPresented: $showingTimeline) {
            TimelineView(viewModel: viewModel, onClose: { showingTimeline = false })
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .home:
            HomeView(
                viewModel: viewModel,
                hasStock: !stockViewModel.batches.isEmpty,
                coverDaysText: coverDaysText,
                onAddDelivery: { selectedTab = .stock }
            )
        case .stock:
            StockView(
                viewModel: stockViewModel,
                onAddDelivery: { presentedSheet = .addDelivery }
            )
        case .alerts:
            AlertsView(viewModel: alertsViewModel)
        case .you:
            YouView(
                viewModel: viewModel,
                onOpenTimeline: { showingTimeline = true },
                onCalibrate: { presentedSheet = .calibration }
            )
        }
    }

    private var bar: some View {
        HStack(spacing: 12) {
            CustomTabBar(selection: $selectedTab)
            FloatingLogButton { presentedSheet = .log }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 6)
    }

    // MARK: - Cross-domain composition

    /// Stock alone can't know how fast it is being used, and the factor view model
    /// doesn't know what's on hand — so the estimate is derived here and handed to
    /// `StockViewModel`, keeping the two domains independent of each other.
    private func syncConsumptionEstimate() {
        stockViewModel.averageDailyConsumptionIU = viewModel.averageDailyDoseIU()
    }

    /// Alerts fire off the decay curve, which only the factor view model knows about.
    /// Same arrangement as the stock estimate: composed here so neither side has to
    /// know the other exists.
    private func syncAlertSchedule() async {
        await alertsViewModel.refreshSchedule(
            model: viewModel.model,
            currentRealPercent: viewModel.currentRealLevelPercent
        )
    }

    private var coverDaysText: String? {
        guard let days = stockViewModel.daysOfCoverage else { return nil }
        return days == 1 ? "1 day" : "\(days) days"
    }
}

#Preview {
    AppShellView(
        viewModel: {
            var settings = AppSettings.defaultSettings
            settings.hasCompletedOnboarding = true
            return FactorTrackerViewModel(settings: settings)
        }(),
        stockViewModel: StockViewModel(),
        alertsViewModel: AlertsViewModel()
    )
}

#Preview("Onboarding") {
    AppShellView(
        viewModel: FactorTrackerViewModel(settings: .defaultSettings),
        stockViewModel: StockViewModel(),
        alertsViewModel: AlertsViewModel()
    )
}
