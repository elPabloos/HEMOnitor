//
//  StockViewModel.swift
//  HEMOnitor
//

import Foundation

/// View model for the Stock tab: the vial inventory (`StockBatch`), kept
/// sorted by expiry so the soonest-to-expire lot is always first.
///
/// Mirrors `FactorTrackerViewModel`'s two-init pattern: `init(batches:)` is
/// in-memory only, for previews and tests; `init(repository:)` loads from and
/// persists through the shared `AppRepository`.
final class StockViewModel: ObservableObject {
    @Published private(set) var batches: [StockBatch]

    /// Estimated IU consumed per day, used only to compute `daysOfCoverage` for
    /// the hero card's "Covers" row. This screen has no access to injection
    /// history (`FactorTrackerViewModel` isn't passed in — see task 013's
    /// Integration notes), so there is no real consumption rate to derive it
    /// from yet. Defaults to `nil`, in which case `daysOfCoverage` is `nil` and
    /// the view shows a placeholder instead of a fabricated number.
    @Published var averageDailyConsumptionIU: Double?

    /// When present, batch changes are persisted through it. Nil for
    /// previews/tests that don't need on-disk persistence.
    private let repository: AppRepository?

    // MARK: - Initialization

    /// In-memory initialization from an explicit batch list — for previews and
    /// tests. Nothing is persisted.
    init(batches: [StockBatch] = []) {
        self.repository = nil
        self.batches = batches.sorted { $0.expiryDate < $1.expiryDate }
    }

    /// Persistence-backed initialization: loads the stock batches saved by
    /// `repository`, then persists any further change through it.
    init(repository: AppRepository) {
        self.repository = repository
        self.batches = repository.state.stockBatches.sorted { $0.expiryDate < $1.expiryDate }
    }

    // MARK: - Totals

    /// Total IU across every lot (vial size × quantity, summed).
    var totalIU: Double {
        batches.reduce(0) { $0 + $1.vialSizeIU * Double($1.quantity) }
    }

    /// Total vial count across every lot.
    var totalVialCount: Int {
        batches.reduce(0) { $0 + $1.quantity }
    }

    /// The earliest expiry date across every lot, or nil when there's no stock.
    var soonestExpiry: Date? {
        batches.map(\.expiryDate).min()
    }

    /// Whole days the current stock covers at `averageDailyConsumptionIU`, or
    /// nil when that rate hasn't been supplied (see the property's doc comment).
    var daysOfCoverage: Int? {
        guard let averageDailyConsumptionIU, averageDailyConsumptionIU > 0 else { return nil }
        return Int(totalIU / averageDailyConsumptionIU)
    }

    // MARK: - Mutations

    /// Adds a newly delivered batch and keeps the list sorted by expiry.
    func addBatch(_ batch: StockBatch) {
        batches.append(batch)
        batches.sort { $0.expiryDate < $1.expiryDate }
        persist()
    }

    /// Removes a batch entirely (e.g. it was entered in error, or fully used up).
    func removeBatch(id: UUID) {
        batches.removeAll { $0.id == id }
        persist()
    }

    /// Decrements `fromBatchId`'s quantity by `vials`.
    ///
    /// Design decision: a consumption that would take a batch below zero is
    /// **rejected, not clamped** — the call fails and the caller must surface
    /// that rather than have stock silently go negative. Returns `true` on
    /// success, `false` if the batch doesn't exist, `vials` isn't positive, or
    /// there isn't enough quantity left in that lot.
    @discardableResult
    func consume(vials: Int, fromBatchId id: UUID) -> Bool {
        guard vials > 0, let index = batches.firstIndex(where: { $0.id == id }) else { return false }
        guard batches[index].quantity - vials >= 0 else { return false }
        batches[index].quantity -= vials
        persist()
        return true
    }

    // MARK: - Persistence

    private func persist() {
        guard let repository else { return }
        let batches = batches
        repository.updateStockBatches { $0 = batches }
    }
}
