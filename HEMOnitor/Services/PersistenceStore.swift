//
//  PersistenceStore.swift
//  HEMOnitor
//

import Foundation

/// Abstractizare pentru citirea/scrierea `AppState`. `FileManagerPersistenceStore`
/// e implementarea reală (JSON pe disc); `InMemoryPersistenceStore` e pentru
/// previews/teste, ca să nu atingă disk-ul.
protocol PersistenceStore {
    func load() -> AppState
    func save(_ state: AppState)
}
