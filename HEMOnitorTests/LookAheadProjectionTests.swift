//
//  LookAheadProjectionTests.swift
//  HEMOnitorTests
//

import Testing
import Foundation
@testable import HEMOnitor

/// Covers `DecayCurve.projectedRealPercent`, the function behind Home's "look ahead"
/// slider. The slider previously moved nothing but a caption; these pin down the
/// projection it now drives so the regression can't come back silently.
struct LookAheadProjectionTests {

    private func model(calibration: Double? = nil) -> FactorVIIIModel {
        var m = FactorVIIIModel(weightKg: 65, baselinePercent: 2, halfLifeHours: 19)
        m.calibrationFactor = calibration
        return m
    }

    private func isClose(_ a: Double, _ b: Double, _ tolerance: Double = 1e-9) -> Bool {
        abs(a - b) < tolerance
    }

    @Test func zeroHoursLeavesTheCurrentLevelUntouched() {
        let projected = DecayCurve.projectedRealPercent(
            model: model(),
            currentRealPercent: 78,
            hoursAhead: 0
        )
        #expect(isClose(projected, 78))
    }

    @Test func oneHalfLifeAheadHalvesTheInfusedComponent() {
        let projected = DecayCurve.projectedRealPercent(
            model: model(),
            currentRealPercent: 78,
            hoursAhead: 19
        )
        // Baseline is the floor the infused component decays toward, not zero.
        #expect(isClose(projected, 2 + (78 - 2) * 0.5))
    }

    @Test func projectionDecreasesMonotonicallyWithTime() {
        let m = model()
        let hours: [Double] = [0, 6, 12, 24, 48, 72]
        let levels = hours.map {
            DecayCurve.projectedRealPercent(model: m, currentRealPercent: 78, hoursAhead: $0)
        }
        for (earlier, later) in zip(levels, levels.dropFirst()) {
            #expect(later < earlier)
        }
    }

    @Test func projectionNeverFallsBelowBaseline() {
        let projected = DecayCurve.projectedRealPercent(
            model: model(),
            currentRealPercent: 78,
            hoursAhead: 10_000
        )
        #expect(projected >= 2)
    }

    @Test func negativeHoursAreTreatedAsNow() {
        // The slider can't go negative, but the guard shouldn't hand `levelAtTime` a
        // negative offset — it returns the peak unchanged for those.
        let projected = DecayCurve.projectedRealPercent(
            model: model(),
            currentRealPercent: 78,
            hoursAhead: -5
        )
        #expect(isClose(projected, 78))
    }

    @Test func projectionStaysInRealSpaceRegardlessOfCalibration() {
        // Calibration must not leak into the projection — it is applied later, when
        // the projected real value is converted for display.
        let plain = DecayCurve.projectedRealPercent(
            model: model(),
            currentRealPercent: 78,
            hoursAhead: 19
        )
        let calibrated = DecayCurve.projectedRealPercent(
            model: model(calibration: 2),
            currentRealPercent: 78,
            hoursAhead: 19
        )
        #expect(isClose(plain, calibrated))
    }

    @Test func displayConversionScalesTheProjectedValue() {
        let m = model(calibration: 1.5)
        let projected = DecayCurve.projectedRealPercent(
            model: m,
            currentRealPercent: 78,
            hoursAhead: 19
        )
        #expect(isClose(m.displayLevel(fromRealPercent: projected), projected * 1.5))
    }

    @Test func projectionMatchesTheCurveSampleAtTheSameHour() {
        // Home draws the curve from the projected level; the two must agree, or the
        // curve would start somewhere other than the number above it.
        let m = model()
        let hoursAhead: Double = 24
        let projected = DecayCurve.projectedRealPercent(
            model: m,
            currentRealPercent: 78,
            hoursAhead: hoursAhead
        )
        let sampled = m.levelAtTime(peakPercent: 78, hoursSincePeak: hoursAhead)
        #expect(isClose(projected, sampled))
    }
}
