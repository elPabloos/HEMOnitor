//
//  AppShellView.swift
//  HEMOnitor
//

import SwiftUI

/// The app root: a tab destination plus the floating bar overlay.
///
/// Navigation state lives here as plain `@State` rather than in a router object —
/// there are four destinations and one sheet, so an observable router would add
/// indirection without buying anything. Screens that need to steer navigation are
/// handed a closure (`HomeView`'s "no stock" prompt will jump to the Stock tab),
/// matching how the existing card views already take `onAddInjection`/`onCalibrate`.
struct AppShellView: View {
    @ObservedObject var viewModel: FactorTrackerViewModel

    @State private var selectedTab: AppTab = .home
    @State private var isShowingLogSheet = false

    /// Height reserved at the bottom so scrolling content clears the floating bar.
    private let barClearance: CGFloat = 86

    var body: some View {
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
        .sheet(isPresented: $isShowingLogSheet) {
            // Replaced by the real log sheet in the sheet-system phase.
            ComingSoonView(tab: .home)
                .background(AppColor.backgroundGradient)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .home:
            HomeView(viewModel: viewModel)
        case .stock, .alerts, .you:
            ComingSoonView(tab: selectedTab)
        }
    }

    private var bar: some View {
        HStack(spacing: 12) {
            CustomTabBar(selection: $selectedTab)
            FloatingLogButton { isShowingLogSheet = true }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 6)
    }
}

#Preview {
    AppShellView(viewModel: FactorTrackerViewModel())
}
