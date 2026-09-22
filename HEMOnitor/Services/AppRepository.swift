//
//  AppRepository.swift
//  HEMOnitor
//

import Foundation

/// The single access point to the app's persisted state. `HEMOnitorApp` builds
/// one instance and hands it to every ViewModel that needs persistence, so they
/// all write into the same `AppState` — otherwise a naive per-ViewModel `save`
/// would clobber the others' data. Deliberately not an `ObservableObject`: each
/// ViewModel remains the source of truth for its own `@Published` state, and
/// `AppRepository` is just a Model-layer persistence service.
final class AppRepository {
    private let store: PersistenceStore
    private(set) var state: AppState

    init(store: PersistenceStore) {
        self.store = store
        self.state = store.load()
    }

    func updateSettings(_ transform: (inout AppSettings) -> Void) {
        transform(&state.settings)
        store.save(state)
    }

    func updateInjections(_ transform: (inout [InjectionEvent]) -> Void) {
        transform(&state.injections)
        store.save(state)
    }

    func updateStockBatches(_ transform: (inout [StockBatch]) -> Void) {
        transform(&state.stockBatches)
        store.save(state)
    }

    func updateAlertSettings(_ transform: (inout AlertSettings) -> Void) {
        transform(&state.alertSettings)
        store.save(state)
    }
}
