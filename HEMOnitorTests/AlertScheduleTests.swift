//
//  AlertScheduleTests.swift
//  HEMOnitorTests
//

import Testing
import Foundation
@testable import HEMOnitor

struct AlertScheduleTests {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func model() -> FactorVIIIModel {
        FactorVIIIModel(weightKg: 65, baselinePercent: 2, halfLifeHours: 19)
    }

    /// Reminders on, threshold 15%, 6h warning, follow-up off.
    private func settings(
        enabled: Bool = true,
        threshold: Double = 15,
        lead: Double = 6,
        followUp: Bool = false,
        followUpHours: Double = 4
    ) -> AlertSettings {
        AlertSettings(
            remindersEnabled: enabled,
            crossingThresholdPercent: threshold,
            leadTimeHours: lead,
            missedDoseFollowUpEnabled: followUp,
            missedDoseFollowUpHours: followUpHours
        )
    }

    private func hours(from a: Date, to b: Date) -> Double {
        b.timeIntervalSince(a) / 3600
    }

    // MARK: - Crossing time

    /// From 42% real down to 15%: 19 * log2(40/13) = 30.8 hours.
    @Test func crossingIsPredictedFromTheDecayCurve() {
        let crossing = AlertSchedule.crossingDate(
            settings: settings(),
            model: model(),
            currentRealPercent: 42,
            now: now
        )
        let expected = 19 * log2(Double(42 - 2) / Double(15 - 2))
        #expect(crossing != nil)
        #expect(abs(hours(from: now, to: crossing ?? now) - expected) < 1e-6)
    }

    /// The threshold is set in display terms, so with calibration active it has to be
    /// converted back to real space — otherwise the alert fires at the wrong level.
    @Test func thresholdIsConvertedOutOfDisplaySpace() {
        var calibrated = model()
        calibrated.calibrationFactor = 0.5

        let crossing = AlertSchedule.crossingDate(
            settings: settings(threshold: 15),
            model: calibrated,
            currentRealPercent: 42,
            now: now
        )
        // 15% displayed is 30% real, reached far sooner than 15% real would be.
        let expected = 19 * log2(Double(42 - 2) / Double(30 - 2))
        #expect(abs(hours(from: now, to: crossing ?? now) - expected) < 1e-6)
    }

    @Test func noCrossingWhenAlreadyBelowTheThreshold() {
        let crossing = AlertSchedule.crossingDate(
            settings: settings(threshold: 15),
            model: model(),
            currentRealPercent: 10,
            now: now
        )
        #expect(crossing == nil)
    }

    // MARK: - Which alerts get scheduled

    @Test func schedulesNothingWhenRemindersAreOff() {
        let alerts = AlertSchedule.alerts(
            settings: settings(enabled: false),
            model: model(),
            currentRealPercent: 42,
            now: now
        )
        #expect(alerts.isEmpty)
    }

    @Test func warningFiresTheLeadTimeBeforeTheCrossing() {
        let crossing = AlertSchedule.crossingDate(settings: settings(), model: model(), currentRealPercent: 42, now: now)!
        let alerts = AlertSchedule.alerts(settings: settings(lead: 6), model: model(), currentRealPercent: 42, now: now)

        #expect(alerts.count == 1)
        #expect(alerts[0].kind == .crossing)
        #expect(abs(hours(from: alerts[0].fireDate, to: crossing) - 6) < 1e-6)
    }

    /// A warning whose moment has already gone is dropped — iOS won't deliver a
    /// past-dated notification, and the app is on screen anyway.
    @Test func warningIsDroppedWhenItsMomentHasPassed() {
        // Crossing is ~30.8h away but the lead time is 48h, putting the warning in the past.
        let alerts = AlertSchedule.alerts(
            settings: settings(lead: 48),
            model: model(),
            currentRealPercent: 42,
            now: now
        )
        #expect(alerts.contains { $0.kind == .crossing } == false)
    }

    @Test func followUpIsScheduledAfterTheCrossingOnlyWhenEnabled() {
        let crossing = AlertSchedule.crossingDate(settings: settings(), model: model(), currentRealPercent: 42, now: now)!

        let without = AlertSchedule.alerts(settings: settings(followUp: false), model: model(), currentRealPercent: 42, now: now)
        #expect(without.contains { $0.kind == .missedDoseFollowUp } == false)

        let with = AlertSchedule.alerts(
            settings: settings(followUp: true, followUpHours: 4),
            model: model(),
            currentRealPercent: 42,
            now: now
        )
        let followUp = with.first { $0.kind == .missedDoseFollowUp }
        #expect(followUp != nil)
        // After the crossing, not before it.
        #expect(abs(hours(from: crossing, to: followUp?.fireDate ?? now) - 4) < 1e-6)
    }

    /// Ids are stable per kind, so rescheduling replaces rather than accumulates.
    @Test func alertIdsAreStablePerKind() {
        let first = AlertSchedule.alerts(settings: settings(followUp: true), model: model(), currentRealPercent: 42, now: now)
        let second = AlertSchedule.alerts(settings: settings(followUp: true), model: model(), currentRealPercent: 30, now: now)

        #expect(Set(first.map(\.id)) == Set(second.map(\.id)))
        #expect(Set(first.map(\.id)).count == first.count)   // no duplicates within a batch
    }

    @Test func copyNamesTheThreshold() {
        let alert = ScheduledAlert(kind: .crossing, fireDate: now, thresholdDisplayPercent: 15)
        #expect(AlertSchedule.body(for: alert).contains("15%"))
        #expect(AlertSchedule.title(for: .crossing) != AlertSchedule.title(for: .missedDoseFollowUp))
    }
}
