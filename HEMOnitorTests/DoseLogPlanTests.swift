//
//  DoseLogPlanTests.swift
//  HEMOnitorTests
//

import Testing
import Foundation
@testable import HEMOnitor

struct DoseLogPlanTests {

    private func model() -> FactorVIIIModel {
        FactorVIIIModel(weightKg: 65, baselinePercent: 2, halfLifeHours: 19)
    }

    private func batch(_ size: Double, _ quantity: Int, id: UUID = UUID()) -> StockBatch {
        StockBatch(
            id: id,
            productName: "Elocta",
            lotNumber: "L1",
            expiryDate: Date(timeIntervalSince1970: 2_000_000_000),
            vialSizeIU: size,
            quantity: quantity
        )
    }

    private func isClose(_ a: Double, _ b: Double, _ tolerance: Double = 1e-9) -> Bool {
        abs(a - b) < tolerance
    }

    // MARK: - Vial totalling

    @Test func totalsSelectedVialsAcrossBatches() {
        let a = batch(1500, 4), b = batch(500, 2)
        let total = DoseLogPlan.totalIU(selection: [a.id: 2, b.id: 1], batches: [a, b])
        #expect(isClose(total, 3500))   // 2*1500 + 1*500
    }

    /// A selection referring to a batch that no longer exists must be skipped, not
    /// silently counted as zero units of a real vial — otherwise a stale selection
    /// would log a smaller dose than the user chose.
    @Test func ignoresSelectionsForUnknownBatches() {
        let a = batch(1000, 2)
        let total = DoseLogPlan.totalIU(selection: [a.id: 1, UUID(): 5], batches: [a])
        #expect(isClose(total, 1000))
    }

    @Test func emptyOrZeroSelectionTotalsNothing() {
        let a = batch(1000, 2)
        #expect(isClose(DoseLogPlan.totalIU(selection: [:], batches: [a]), 0))
        #expect(isClose(DoseLogPlan.totalIU(selection: [a.id: 0], batches: [a]), 0))
    }

    // MARK: - Predicted effect

    /// 1300 IU at 65 kg with 2.0 recovery is exactly +40 pp, stacked on the level
    /// present at the time of the dose.
    @Test func predictsPeakStackedOnTheCurrentLevel() {
        let plan = DoseLogPlan.make(doseIU: 1300, model: model(), currentRealPercent: 22)
        #expect(isClose(plan.predictedPeakRealPercent, 62))
        #expect(isClose(plan.predictedPeakDisplayPercent, 62))
    }

    /// The preview is shown to the user, so it must be in display space.
    @Test func predictedPeakIsScaledByCalibration() {
        var calibrated = model()
        calibrated.calibrationFactor = 0.5
        let plan = DoseLogPlan.make(doseIU: 1300, model: calibrated, currentRealPercent: 2)

        #expect(isClose(plan.predictedPeakRealPercent, 42))      // real is untouched
        #expect(isClose(plan.predictedPeakDisplayPercent, 21))   // display is halved
    }

    /// The 5% threshold is quoted in display space, so with calibration active it must
    /// be converted back to real before asking the model about decay — otherwise the
    /// duration would be computed against the wrong target.
    @Test func thresholdIsConvertedOutOfDisplaySpace() {
        var calibrated = model()
        calibrated.calibrationFactor = 0.5
        let plan = DoseLogPlan.make(
            doseIU: 1300,
            model: calibrated,
            currentRealPercent: 2,
            thresholdDisplayPercent: 5
        )

        // 5% displayed is 10% real; from a real peak of 42: 19 * log2(40/8) = 44.1h
        let expected: Double = 19 * log2(Double(42 - 2) / Double(10 - 2))
        #expect(plan.hoursUntilThreshold != nil)
        #expect(isClose(plan.hoursUntilThreshold ?? 0, expected, 1e-6))
    }

    @Test func thresholdIsNilWhenTheDoseNeverReachesIt() {
        // A dose so small the peak sits below the threshold already.
        let plan = DoseLogPlan.make(
            doseIU: 1,
            model: model(),
            currentRealPercent: 2,
            thresholdDisplayPercent: 40
        )
        #expect(plan.hoursUntilThreshold == nil)
    }

    // MARK: - Stock after

    @Test func stockAfterSubtractsTheDoseAndNeverGoesNegative() {
        let withStock = DoseLogPlan.make(doseIU: 1500, model: model(), currentRealPercent: 2, stockTotalIU: 4000)
        #expect(isClose(withStock.stockAfterIU ?? -1, 2500))

        let overdrawn = DoseLogPlan.make(doseIU: 5000, model: model(), currentRealPercent: 2, stockTotalIU: 4000)
        #expect(isClose(overdrawn.stockAfterIU ?? -1, 0))

        let manual = DoseLogPlan.make(doseIU: 1500, model: model(), currentRealPercent: 2)
        #expect(manual.stockAfterIU == nil)
    }

    // MARK: - Duration formatting

    @Test func formatsDurationsByMagnitude() {
        #expect(DoseLogPlan.formattedDuration(0.5) == "30 min")
        #expect(DoseLogPlan.formattedDuration(18) == "18.0 h")
        #expect(DoseLogPlan.formattedDuration(60) == "2.5 days")
    }
}
