//
//  InMemoryPersistenceStore.swift
//  HEMOnitor
//

import Foundation

/// Store în memorie, fără disc — pentru previews și teste.
final class InMemoryPersistenceStore: PersistenceStore {
    private var state: AppState

    init(initialState: AppState = AppState()) {
        self.state = initialState
    }

    func load() -> AppState { state }
    func save(_ state: AppState) { self.state = state }
}
