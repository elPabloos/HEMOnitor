//
//  AppRepository.swift
//  HEMOnitor
//

import Foundation

/// Punct unic de acces la starea persistată a aplicației. `HEMOnitorApp`
/// construiește o singură instanță și o dă mai departe fiecărui ViewModel care
/// are nevoie de persistență, astfel încât toate să scrie în același
/// `AppState` — altfel un `save` naiv per-ViewModel ar suprascrie datele
/// celorlalte. Nu e `ObservableObject`: fiecare ViewModel rămâne sursa de
/// adevăr pentru propriile `@Published`, `AppRepository` e doar un serviciu
/// de persistență la nivel de Model.
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
