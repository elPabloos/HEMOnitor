//
//  AppState.swift
//  HEMOnitor
//

import Foundation

/// A complete snapshot of the app's persisted data — everything
/// `PersistenceStore` writes into a single JSON file.
struct AppState: Codable, Equatable {
    var settings: AppSettings = .defaultSettings
    var injections: [InjectionEvent] = []
    var stockBatches: [StockBatch] = []
    var alertSettings: AlertSettings = AlertSettings()
}
