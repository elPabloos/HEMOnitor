//
//  HEMOnitorApp.swift
//  HEMOnitor
//
//  Created by Ciudin, Paul-Catalin on 05.08.2025.
//

import SwiftUI

@main
struct HEMOnitorApp: App {
    /// Instanță unică, dată mai departe fiecărui ViewModel care are nevoie de
    /// persistență, ca toate să scrie în același `AppState`.
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
            ContentView(viewModel: viewModel)
        }
    }
}
