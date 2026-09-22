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

    init() {
        FontRegistrar.registerBundledFontsIfNeeded()
        let repository = AppRepository(store: FileManagerPersistenceStore())
        self.repository = repository
        _viewModel = StateObject(wrappedValue: FactorTrackerViewModel(repository: repository))
    }

    var body: some Scene {
        WindowGroup {
            AppShellView(viewModel: viewModel)
        }
    }
}
