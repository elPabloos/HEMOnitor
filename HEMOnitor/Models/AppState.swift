//
//  AppState.swift
//  HEMOnitor
//

import Foundation

/// Instantaneul complet al datelor persistate ale aplicației — tot ce salvează
/// `PersistenceStore` într-un singur fișier JSON.
struct AppState: Codable, Equatable {
    var settings: AppSettings = .defaultSettings
    var injections: [InjectionEvent] = []
    var stockBatches: [StockBatch] = []
    var alertSettings: AlertSettings = AlertSettings()
}
