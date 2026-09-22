//
//  DoseLogPlan.swift
//  HEMOnitor
//

import Foundation

/// The numbers previewed in the log sheet before a dose is committed: what the
/// dose comes to, where it will put the level, how long that lasts, and what stock
/// is left afterwards.
///
/// Deliberately a plain value type with a pure factory and no SwiftUI import, so the
/// arithmetic can be tested without standing up a view. All of it is derived from
/// `FactorVIIIModel` — no new pharmacokinetics here.
struct DoseLogPlan: Equatable {
    /// Total units being administered.
    let doseIU: Double
    /// Level immediately after the dose, in real (uncalibrated) space.
    let predictedPeakRealPercent: Double
    /// The same peak, scaled for display.
    let predictedPeakDisplayPercent: Double
    /// Hours until the level decays back to the threshold, or nil if unreachable.
    let hoursUntilThreshold: Double?
    /// Units left in stock once this dose is taken out, or nil when logging manually.
    let stockAfterIU: Double?

    /// Sums the selected vials. Counts referring to an unknown batch are ignored
    /// rather than treated as zero-size, so a stale selection can't silently
    /// under-count the dose.
    static func totalIU(selection: [UUID: Int], batches: [StockBatch]) -> Double {
        selection.reduce(into: 0) { total, entry in
            guard let batch = batches.first(where: { $0.id == entry.key }) else { return }
            total += Double(max(0, entry.value)) * batch.vialSizeIU
        }
    }

    static func make(
        doseIU: Double,
        model: FactorVIIIModel,
        currentRealPercent: Double,
        thresholdDisplayPercent: Double = 5,
        stockTotalIU: Double? = nil
    ) -> DoseLogPlan {
        let peakReal = model.newPeakAfterAdditionalDose(
            doseIU: doseIU,
            currentRealLevelPercent: currentRealPercent
        )
        // The threshold is expressed in display space (that's what the user reads),
        // so convert it back to real space before asking the model about decay.
        let thresholdReal = model.realPercent(fromDisplayPercent: thresholdDisplayPercent)

        return DoseLogPlan(
            doseIU: doseIU,
            predictedPeakRealPercent: peakReal,
            predictedPeakDisplayPercent: model.displayLevel(fromRealPercent: peakReal),
            hoursUntilThreshold: model.hoursUntilLevelReaches(
                targetRealPercent: thresholdReal,
                fromRealPercent: peakReal
            ),
            stockAfterIU: stockTotalIU.map { max(0, $0 - doseIU) }
        )
    }

    /// "2.3 days" / "18 h" / "45 min", matching how the rest of the app phrases durations.
    static func formattedDuration(_ hours: Double) -> String {
        if hours < 1 {
            return String(format: "%.0f min", hours * 60)
        } else if hours < 48 {
            return String(format: "%.1f h", hours)
        } else {
            return String(format: "%.1f days", hours / 24)
        }
    }
}
