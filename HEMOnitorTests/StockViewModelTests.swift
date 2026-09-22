//
//  StockViewModelTests.swift
//  HEMOnitorTests
//
//  Covers StockViewModel's logic: totals, expiry-sort ordering, the
//  reject-below-zero consumption rule, and persistence. No SwiftUI views here.
//

import Testing
import Foundation
@testable import HEMOnitor

struct StockViewModelTests {

    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    private func date(_ daysFromBase: Double) -> Date {
        base.addingTimeInterval(daysFromBase * 86400)
    }

    private func makeBatch(
        lotNumber: String = "L1",
        expiryDays: Double,
        vialSizeIU: Double = 1000,
        quantity: Int = 2
    ) -> StockBatch {
        StockBatch(
            productName: "Elocta",
            lotNumber: lotNumber,
            expiryDate: date(expiryDays),
            vialSizeIU: vialSizeIU,
            quantity: quantity
        )
    }

    // MARK: - Empty state

    @Test func emptyStateHasZeroedTotalsAndNoSoonestExpiry() {
        let viewModel = StockViewModel(batches: [])

        #expect(viewModel.totalIU == 0)
        #expect(viewModel.totalVialCount == 0)
        #expect(viewModel.soonestExpiry == nil)
        #expect(viewModel.daysOfCoverage == nil)
    }

    // MARK: - Sorting

    @Test func batchesAreKeptSortedByExpiryAscendingRegardlessOfInsertionOrder() {
        let viewModel = StockViewModel(batches: [
            makeBatch(lotNumber: "later", expiryDays: 400),
            makeBatch(lotNumber: "soonest", expiryDays: 5),
            makeBatch(lotNumber: "middle", expiryDays: 100)
        ])

        #expect(viewModel.batches.map(\.lotNumber) == ["soonest", "middle", "later"])
    }

    @Test func addBatchInsertsInExpiryOrder() {
        let viewModel = StockViewModel(batches: [
            makeBatch(lotNumber: "existing", expiryDays: 50)
        ])

        viewModel.addBatch(makeBatch(lotNumber: "earlier", expiryDays: 10))
        viewModel.addBatch(makeBatch(lotNumber: "latest", expiryDays: 900))

        #expect(viewModel.batches.map(\.lotNumber) == ["earlier", "existing", "latest"])
    }

    // MARK: - Totals

    @Test func totalsSumAcrossAllBatches() {
        let viewModel = StockViewModel(batches: [
            makeBatch(lotNumber: "a", expiryDays: 10, vialSizeIU: 1500, quantity: 3),
            makeBatch(lotNumber: "b", expiryDays: 20, vialSizeIU: 750, quantity: 2)
        ])

        #expect(viewModel.totalIU == 1500 * 3 + 750 * 2)
        #expect(viewModel.totalVialCount == 5)
        #expect(viewModel.soonestExpiry == date(10))
    }

    @Test func daysOfCoverageDividesTotalIUByTheSuppliedDailyRate() {
        let viewModel = StockViewModel(batches: [
            makeBatch(lotNumber: "a", expiryDays: 10, vialSizeIU: 1000, quantity: 5) // 5000 IU
        ])
        viewModel.averageDailyConsumptionIU = 500

        #expect(viewModel.daysOfCoverage == 10)
    }

    @Test func daysOfCoverageIsNilWhenTheDailyRateIsUnsetOrNonPositive() {
        let viewModel = StockViewModel(batches: [
            makeBatch(lotNumber: "a", expiryDays: 10, vialSizeIU: 1000, quantity: 5)
        ])

        #expect(viewModel.daysOfCoverage == nil)

        viewModel.averageDailyConsumptionIU = 0
        #expect(viewModel.daysOfCoverage == nil)

        viewModel.averageDailyConsumptionIU = -100
        #expect(viewModel.daysOfCoverage == nil)
    }

    // MARK: - removeBatch

    @Test func removeBatchDropsOnlyTheMatchingLot() {
        let keep = makeBatch(lotNumber: "keep", expiryDays: 10)
        let drop = makeBatch(lotNumber: "drop", expiryDays: 20)
        let viewModel = StockViewModel(batches: [keep, drop])

        viewModel.removeBatch(id: drop.id)

        #expect(viewModel.batches.map(\.id) == [keep.id])
    }

    @Test func removeBatchWithUnknownIdChangesNothing() {
        let batch = makeBatch(expiryDays: 10)
        let viewModel = StockViewModel(batches: [batch])

        viewModel.removeBatch(id: UUID())

        #expect(viewModel.batches.count == 1)
    }

    // MARK: - consume: the reject-below-zero rule

    @Test func consumeDecrementsQuantityWhenEnoughStockRemains() {
        let batch = makeBatch(expiryDays: 10, quantity: 5)
        let viewModel = StockViewModel(batches: [batch])

        let ok = viewModel.consume(vials: 3, fromBatchId: batch.id)

        #expect(ok == true)
        #expect(viewModel.batches.first?.quantity == 2)
    }

    @Test func consumeExactlyToZeroSucceeds() {
        let batch = makeBatch(expiryDays: 10, quantity: 4)
        let viewModel = StockViewModel(batches: [batch])

        let ok = viewModel.consume(vials: 4, fromBatchId: batch.id)

        #expect(ok == true)
        #expect(viewModel.batches.first?.quantity == 0)
    }

    /// The core design decision under test: a consumption that would take a
    /// batch negative must be rejected outright, not clamped to zero.
    @Test func consumeBeyondAvailableQuantityIsRejectedAndLeavesQuantityUnchanged() {
        let batch = makeBatch(expiryDays: 10, quantity: 2)
        let viewModel = StockViewModel(batches: [batch])

        let ok = viewModel.consume(vials: 3, fromBatchId: batch.id)

        #expect(ok == false)
        #expect(viewModel.batches.first?.quantity == 2)
    }

    @Test func consumeWithNonPositiveVialsIsRejected() {
        let batch = makeBatch(expiryDays: 10, quantity: 2)
        let viewModel = StockViewModel(batches: [batch])

        #expect(viewModel.consume(vials: 0, fromBatchId: batch.id) == false)
        #expect(viewModel.consume(vials: -1, fromBatchId: batch.id) == false)
        #expect(viewModel.batches.first?.quantity == 2)
    }

    @Test func consumeWithUnknownBatchIdIsRejected() {
        let batch = makeBatch(expiryDays: 10, quantity: 2)
        let viewModel = StockViewModel(batches: [batch])

        #expect(viewModel.consume(vials: 1, fromBatchId: UUID()) == false)
        #expect(viewModel.batches.first?.quantity == 2)
    }

    // MARK: - Persistence

    @Test func batchChangesPersistThroughTheRepository() {
        let store = InMemoryPersistenceStore()
        let viewModel = StockViewModel(repository: AppRepository(store: store))

        let batch = makeBatch(lotNumber: "L1", expiryDays: 30, quantity: 5)
        viewModel.addBatch(batch)
        viewModel.consume(vials: 2, fromBatchId: batch.id)

        let reloaded = StockViewModel(repository: AppRepository(store: store))

        #expect(reloaded.batches.count == 1)
        #expect(reloaded.batches.first?.quantity == 3)
        #expect(reloaded.batches.first?.lotNumber == "L1")
    }

    @Test func removalPersistsThroughTheRepository() {
        let store = InMemoryPersistenceStore()
        let viewModel = StockViewModel(repository: AppRepository(store: store))

        let batch = makeBatch(expiryDays: 30)
        viewModel.addBatch(batch)
        viewModel.removeBatch(id: batch.id)

        let reloaded = StockViewModel(repository: AppRepository(store: store))
        #expect(reloaded.batches.isEmpty)
    }
}
