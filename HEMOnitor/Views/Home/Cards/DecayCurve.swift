//
//  DecayCurve.swift
//  HEMOnitor
//

import Foundation

/// One sample of the forward decay projection used by the "curve" visualization
/// style.
struct DecayCurvePoint: Identifiable {
    var id: Double { hoursFromNow }
    let hoursFromNow: Double
    let displayPercent: Double
}

/// Pure sampling of the decay curve, in DISPLAY space — each REAL sample is
/// converted with `model.displayLevel(fromRealPercent:)` at the very end, never
/// decayed in display space directly (see CLAUDE.md, "real vs. display level").
///
/// Uses `model.levelAtTime(peakPercent:hoursSincePeak:)` with the *current* real
/// level standing in for `peakPercent` and hours measured forward from "now".
/// This is valid by the same memoryless property of the exponential decay that
/// `FactorVIIIModel.hoursUntilLevelReaches` already relies on: continuing the
/// decay from "now" for `h` more hours produces the same value as continuing it
/// from the true last-injection peak for `(elapsed so far) + h` hours. No new PK
/// math — this is a read-only reuse of `levelAtTime`.
enum DecayCurve {
    static func sample(
        model: FactorVIIIModel,
        currentRealPercent: Double,
        totalHours: Double = 96,
        pointCount: Int = 49
    ) -> [DecayCurvePoint] {
        guard pointCount > 1, totalHours > 0 else { return [] }
        let step = totalHours / Double(pointCount - 1)
        return (0..<pointCount).map { index in
            let hours = Double(index) * step
            let real = model.levelAtTime(peakPercent: currentRealPercent, hoursSincePeak: hours)
            let display = model.displayLevel(fromRealPercent: real)
            return DecayCurvePoint(hoursFromNow: hours, displayPercent: display)
        }
    }
}
