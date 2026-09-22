//
//  AlertSettings.swift
//  HEMOnitor
//

import Foundation

/// Preferințele de alertare pe scăderea nivelului. Folosite de ecranul Alerts
/// (fază ulterioară); modelul e introdus acum ca parte a stratului de persistență.
struct AlertSettings: Codable, Equatable {
    var remindersEnabled: Bool = false
    var crossingThresholdPercent: Double = 15
    var leadTimeHours: Double = 6
    var missedDoseFollowUpEnabled: Bool = false
    var missedDoseFollowUpHours: Double = 4

    /// Identificatorii `UNNotificationRequest` programate curent, ca să poată fi anulate/reprogramate.
    var scheduledAlertIdentifiers: [String] = []
}
