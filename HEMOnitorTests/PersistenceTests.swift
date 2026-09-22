//
//  PersistenceTests.swift
//  HEMOnitorTests
//

import Testing
import Foundation
@testable import HEMOnitor

struct PersistenceTests {

    private func makeTempStore() -> (store: FileManagerPersistenceStore, fileName: String) {
        let fileName = "app_state_test_\(UUID().uuidString).json"
        return (FileManagerPersistenceStore(fileName: fileName), fileName)
    }

    private func cleanUp(_ fileName: String) {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.removeItem(at: dir.appendingPathComponent(fileName))
    }

    @Test func loadWithoutAnExistingFileReturnsDefaults() {
        let (store, fileName) = makeTempStore()
        defer { cleanUp(fileName) }
        let state = store.load()
        #expect(state == AppState())
        #expect(state.settings == AppSettings.defaultSettings)
    }

    @Test func saveThenLoadRoundTrips() {
        let (store, fileName) = makeTempStore()
        defer { cleanUp(fileName) }
        var state = AppState()
        state.settings.weightKg = 72
        state.settings.hasCompletedOnboarding = true
        state.injections = [
            InjectionEvent(id: UUID(), date: Date(timeIntervalSince1970: 0), doseIU: 1500, realLevelBefore: 2, peakRealPercent: 48)
        ]
        state.stockBatches = [
            StockBatch(
                productName: "Elocta",
                lotNumber: "L123",
                expiryDate: Date(timeIntervalSince1970: 1_000_000),
                vialSizeIU: 1500,
                quantity: 3,
                dateAdded: Date(timeIntervalSince1970: 500_000)
            )
        ]
        state.alertSettings.remindersEnabled = true

        store.save(state)
        let reloaded = store.load()

        #expect(reloaded == state)
    }

    @Test func corruptFileFallsBackToDefaults() throws {
        let (store, fileName) = makeTempStore()
        defer { cleanUp(fileName) }
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let url = dir.appendingPathComponent(fileName)
        try "not valid json {".data(using: .utf8)!.write(to: url)

        let state = store.load()
        #expect(state == AppState())
    }

    @Test func appRepositoryUpdatesPersistThroughToTheStore() {
        let backing = InMemoryPersistenceStore()
        let repository = AppRepository(store: backing)

        repository.updateInjections { injections in
            injections.append(InjectionEvent(id: UUID(), date: Date(), doseIU: 1000, realLevelBefore: 2, peakRealPercent: 30))
        }
        repository.updateStockBatches { batches in
            batches.append(StockBatch(productName: "Elocta", lotNumber: "A1", expiryDate: Date(), vialSizeIU: 1000, quantity: 2))
        }

        // O nouă instanță, citind din același store, trebuie să vadă ambele actualizări.
        let reloaded = AppRepository(store: backing)
        #expect(reloaded.state.injections.count == 1)
        #expect(reloaded.state.stockBatches.count == 1)
    }
}
