//
//  PersistenceStore.swift
//  HEMOnitor
//

import Foundation

/// An abstraction for reading/writing `AppState`. `FileManagerPersistenceStore`
/// is the real implementation (JSON on disk); `InMemoryPersistenceStore` is for
/// previews/tests, so they never touch the disk.
protocol PersistenceStore {
    func load() -> AppState
    func save(_ state: AppState)
}
