//
//  InMemoryPersistenceStore.swift
//  HEMOnitor
//

import Foundation

/// An in-memory store, no disk — for previews and tests.
final class InMemoryPersistenceStore: PersistenceStore {
    private var state: AppState

    init(initialState: AppState = AppState()) {
        self.state = initialState
    }

    func load() -> AppState { state }
    func save(_ state: AppState) { self.state = state }
}
