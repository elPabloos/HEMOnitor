//
//  AlertSchedule.swift
//  HEMOnitor
//

import Foundation

/// A notification the app intends to deliver at a specific moment.
struct ScheduledAlert: Equatable, Identifiable {
    enum Kind: String, Equatable {
        /// "Your level is about to drop below the threshold."
        case crossing
        /// "You crossed the threshold a while ago and haven't logged anything."
        case missedDoseFollowUp
    }

    let kind: Kind
    let fireDate: Date
    /// The threshold that triggered this, in display space (what the user set).
    let thresholdDisplayPercent: Double

    /// Stable across reschedules of the same kind, so replacing the pending set
    /// doesn't accumulate duplicates.
    var id: String { "hemonitor.alert.\(kind.rawValue)" }
}

/// Works out *when* alerts should fire. Pure and free of UserNotifications, so the
/// timing rules can be tested without touching the notification system.
///
/// The app cannot run while closed, and doesn't need to: the decay is a formula, so
/// the crossing moment can be computed once, up front, and handed to iOS to deliver
/// later. Everything here is derived from `FactorVIIIModel` — no new pharmacokinetics.
enum AlertSchedule {

    /// The moment the level is predicted to reach the user's threshold, or nil when
    /// that can't happen (already at or below it, or nothing to decay from).
    static func crossingDate(
        settings: AlertSettings,
        model: FactorVIIIModel,
        currentRealPercent: Double,
        now: Date
    ) -> Date? {
        // The user sets the threshold in display terms, so convert it back to real
        // space before asking the model about decay.
        let thresholdReal = model.realPercent(fromDisplayPercent: settings.crossingThresholdPercent)
        guard let hours = model.hoursUntilLevelReaches(
            targetRealPercent: thresholdReal,
            fromRealPercent: currentRealPercent
        ) else { return nil }
        return now.addingTimeInterval(hours * 3600)
    }

    /// The alerts that should be pending right now.
    ///
    /// Alerts whose moment has already passed are dropped rather than fired
    /// immediately: iOS wouldn't deliver a past-dated notification anyway, and a
    /// reminder about something already visible on screen is noise.
    static func alerts(
        settings: AlertSettings,
        model: FactorVIIIModel,
        currentRealPercent: Double,
        now: Date = Date()
    ) -> [ScheduledAlert] {
        guard settings.remindersEnabled else { return [] }
        guard let crossing = crossingDate(
            settings: settings,
            model: model,
            currentRealPercent: currentRealPercent,
            now: now
        ) else { return [] }

        var result: [ScheduledAlert] = []

        let warningDate = crossing.addingTimeInterval(-settings.leadTimeHours * 3600)
        if warningDate > now {
            result.append(
                ScheduledAlert(
                    kind: .crossing,
                    fireDate: warningDate,
                    thresholdDisplayPercent: settings.crossingThresholdPercent
                )
            )
        }

        if settings.missedDoseFollowUpEnabled {
            let followUpDate = crossing.addingTimeInterval(settings.missedDoseFollowUpHours * 3600)
            if followUpDate > now {
                result.append(
                    ScheduledAlert(
                        kind: .missedDoseFollowUp,
                        fireDate: followUpDate,
                        thresholdDisplayPercent: settings.crossingThresholdPercent
                    )
                )
            }
        }

        return result
    }

    // MARK: - Copy

    static func title(for kind: ScheduledAlert.Kind) -> String {
        switch kind {
        case .crossing: return "Factor level dropping"
        case .missedDoseFollowUp: return "Still below your threshold"
        }
    }

    static func body(for alert: ScheduledAlert) -> String {
        let threshold = Int(alert.thresholdDisplayPercent.rounded())
        switch alert.kind {
        case .crossing:
            return "Your estimated level is heading below \(threshold)%. This is an estimate, not medical advice."
        case .missedDoseFollowUp:
            return "No injection logged since your level passed \(threshold)%. Log one if you've taken it."
        }
    }
}
