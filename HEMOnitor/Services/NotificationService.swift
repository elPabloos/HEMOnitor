//
//  NotificationService.swift
//  HEMOnitor
//

import Foundation
import UserNotifications

/// Whether the user has let the app send notifications.
enum NotificationAuthorization: Equatable {
    /// Never asked — asking is still possible.
    case notDetermined
    case authorized
    /// Refused, or switched off later in Settings. Only the user can undo this,
    /// from iOS Settings — asking again does nothing.
    case denied
}

/// Delivery of the alerts `AlertSchedule` decides on.
///
/// A protocol so the scheduling logic can be exercised against a fake: the real
/// implementation talks to iOS, which a unit test can neither authorize nor inspect.
protocol NotificationScheduling {
    func authorizationStatus() async -> NotificationAuthorization
    /// Returns whether permission was granted. Asking when already decided is a no-op.
    func requestAuthorization() async -> Bool
    /// Replaces every alert this app has pending with `alerts`, returning their ids.
    @discardableResult
    func reschedule(_ alerts: [ScheduledAlert]) async -> [String]
    func cancelAll() async
}

/// The real thing, backed by `UNUserNotificationCenter`.
///
/// Notifications are scheduled as one-shot calendar triggers at an absolute moment,
/// so iOS delivers them whether or not the app is running — which is what makes this
/// work without background execution.
final class NotificationService: NotificationScheduling {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async -> NotificationAuthorization {
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .authorized, .provisional, .ephemeral:
            return .authorized
        default:
            return .denied
        }
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    @discardableResult
    func reschedule(_ alerts: [ScheduledAlert]) async -> [String] {
        // Replace wholesale rather than diffing: the predicted crossing moves every
        // time a dose is logged or a parameter changes, so almost every reschedule
        // would invalidate everything anyway.
        await cancelAll()
        guard await authorizationStatus() == .authorized else { return [] }

        var scheduled: [String] = []
        for alert in alerts {
            let content = UNMutableNotificationContent()
            content.title = AlertSchedule.title(for: alert.kind)
            content.body = AlertSchedule.body(for: alert)
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: alert.fireDate
            )
            let request = UNNotificationRequest(
                identifier: alert.id,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            do {
                try await center.add(request)
                scheduled.append(alert.id)
            } catch {
                // A single failed request shouldn't discard the others.
                assertionFailure("Could not schedule \(alert.id): \(error)")
            }
        }
        return scheduled
    }

    func cancelAll() async {
        let pending = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix("hemonitor.alert.") }
        center.removePendingNotificationRequests(withIdentifiers: pending)
    }
}
