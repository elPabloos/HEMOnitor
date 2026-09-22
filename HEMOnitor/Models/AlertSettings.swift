//
//  AlertSettings.swift
//  HEMOnitor
//

import Foundation

/// Preferences for level-crossing alerts. Used by the Alerts screen (a later
/// phase); the model is introduced now as part of the persistence layer.
struct AlertSettings: Codable, Equatable {
    var remindersEnabled: Bool = false
    var crossingThresholdPercent: Double = 15
    var leadTimeHours: Double = 6
    var missedDoseFollowUpEnabled: Bool = false
    var missedDoseFollowUpHours: Double = 4

    /// Identifiers of the currently scheduled `UNNotificationRequest`s, so they can be cancelled/rescheduled.
    var scheduledAlertIdentifiers: [String] = []
}
