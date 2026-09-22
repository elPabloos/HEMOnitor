//
//  IntegrationHelpersTests.swift
//  HEMOnitorTests
//
//  Covers the two pure helpers the parallel screen phases left untested: the Home
//  curve sampler (its own agent couldn't reach the test target) and the cross-domain
//  consumption estimate added when wiring Stock and Home together.
//

import Testing
import Foundation
@testable import HEMOnitor

struct IntegrationHelpersTests {

    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    private func date(_ hoursFromBase: Double) -> Date {
        base.addingTimeInterval(hoursFromBase * 3600)
    }

    private func isClose(_ a: Double, _ b: Double, _ tolerance: Double = 1e-9) -> Bool {
        abs(a - b) < tolerance
    }

    // MARK: - DecayCurve

    /// The sampler must reproduce the model's own decay, not approximate it: with a
    /// 19 h half-life, 42 % decays to 22 % after one half-life and 12 % after two.
    @Test func decayCurveFollowsTheModelsDecay() {
        let model = FactorVIIIModel(weightKg: 65, baselinePercent: 2, halfLifeHours: 19)
        let points = DecayCurve.sample(
            model: model,
            currentRealPercent: 42,
            totalHours: 38,
            pointCount: 3
        )

        #expect(points.count == 3)
        #expect(isClose(points[0].hoursFromNow, 0))
        #expect(isClose(points[0].displayPercent, 42))
        #expect(isClose(points[1].hoursFromNow, 19))
        #expect(isClose(points[1].displayPercent, 22))
        #expect(isClose(points[2].hoursFromNow, 38))
        #expect(isClose(points[2].displayPercent, 12))
    }

    /// The curve is drawn in display space, so calibration must scale it.
    @Test func decayCurveIsSampledInDisplaySpace() {
        var model = FactorVIIIModel(weightKg: 65, baselinePercent: 2, halfLifeHours: 19)
        model.calibrationFactor = 0.5

        let points = DecayCurve.sample(model: model, currentRealPercent: 42, totalHours: 19, pointCount: 2)

        #expect(isClose(points[0].displayPercent, 21))   // 42 * 0.5
        #expect(isClose(points[1].displayPercent, 11))   // 22 * 0.5
    }

    @Test func decayCurveRejectsDegenerateRequests() {
        let model = FactorVIIIModel(weightKg: 65, baselinePercent: 2, halfLifeHours: 19)
        #expect(DecayCurve.sample(model: model, currentRealPercent: 42, pointCount: 1).isEmpty)
        #expect(DecayCurve.sample(model: model, currentRealPercent: 42, totalHours: 0).isEmpty)
    }

    // MARK: - Average daily consumption

    /// Divides by the window, not by the number of doses — someone dosing twice a
    /// week consumes far less per day than one dose would suggest.
    @Test func averageDailyDoseDividesByTheWindowNotTheDoseCount() {
        let viewModel = FactorTrackerViewModel(settings: .defaultSettings)
        let now = date(0)

        // Two 1400 IU doses inside a 28-day window → 2800 / 28 = 100 IU/day.
        viewModel.addInjection(doseIU: 1400, at: now.addingTimeInterval(-5 * 86_400))
        viewModel.addInjection(doseIU: 1400, at: now.addingTimeInterval(-2 * 86_400))

        let average = viewModel.averageDailyDoseIU(overLastDays: 28, now: now)
        #expect(average != nil)
        #expect(isClose(average ?? 0, 100))
    }

    @Test func averageDailyDoseIgnoresDosesOutsideTheWindow() {
        let viewModel = FactorTrackerViewModel(settings: .defaultSettings)
        let now = date(0)

        viewModel.addInjection(doseIU: 9999, at: now.addingTimeInterval(-60 * 86_400)) // too old
        viewModel.addInjection(doseIU: 300, at: now.addingTimeInterval(-1 * 86_400))

        let average = viewModel.averageDailyDoseIU(overLastDays: 30, now: now)
        #expect(isClose(average ?? 0, 10))   // 300 / 30, the old dose excluded
    }

    @Test func averageDailyDoseIsNilWithoutHistoryInTheWindow() {
        let viewModel = FactorTrackerViewModel(settings: .defaultSettings)
        #expect(viewModel.averageDailyDoseIU(now: date(0)) == nil)

        viewModel.addInjection(doseIU: 1000, at: date(0).addingTimeInterval(-90 * 86_400))
        #expect(viewModel.averageDailyDoseIU(overLastDays: 30, now: date(0)) == nil)
    }
}
