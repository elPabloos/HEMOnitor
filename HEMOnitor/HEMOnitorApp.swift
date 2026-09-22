//
//  HEMOnitorApp.swift
//  HEMOnitor
//
//  Created by Ciudin, Paul-Catalin on 05.08.2025.
//

import SwiftUI

@main
struct HEMOnitorApp: App {
    /// A single instance, handed to every ViewModel that needs persistence, so
    /// they all write into the same `AppState`.
    private let repository: AppRepository
    @StateObject private var viewModel: FactorTrackerViewModel
    @StateObject private var stockViewModel: StockViewModel
    @StateObject private var alertsViewModel: AlertsViewModel

    init() {
        FontRegistrar.registerBundledFontsIfNeeded()
        // One repository shared by every view model, so they all write into the
        // same AppState rather than clobbering each other's slice of it.
        let repository = AppRepository(store: FileManagerPersistenceStore())
        self.repository = repository
        _viewModel = StateObject(wrappedValue: FactorTrackerViewModel(repository: repository))
        _stockViewModel = StateObject(wrappedValue: StockViewModel(repository: repository))
        _alertsViewModel = StateObject(wrappedValue: AlertsViewModel(repository: repository))
    }

    var body: some Scene {
        WindowGroup {
            AppShellView(
                viewModel: viewModel,
                stockViewModel: stockViewModel,
                alertsViewModel: alertsViewModel
            )
        }
    }
}
