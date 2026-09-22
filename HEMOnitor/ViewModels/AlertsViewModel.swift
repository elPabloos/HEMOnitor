//
//  AlertsViewModel.swift
//  HEMOnitor
//

import Foundation
import Combine

/// Owns the alert preferences and keeps the pending notifications in step with them.
///
/// Scheduling depends on the current factor level, which lives in
/// `FactorTrackerViewModel`. Rather than reach across, this exposes
/// `refreshSchedule(model:currentRealPercent:)` and lets the shell — the one place
/// aware of both — supply it, the same arrangement used for the stock cover estimate.
@MainActor
final class AlertsViewModel: ObservableObject {
    @Published private(set) var settings: AlertSettings
    @Published private(set) var authorization: NotificationAuthorization = .notDetermined
    /// What is currently pending, for display on the Alerts screen.
    @Published private(set) var scheduled: [ScheduledAlert] = []

    private let repository: AppRepository?
    private let notifications: NotificationScheduling

    /// The last level we were told about, so a settings change can reschedule
    /// without the shell having to hand it over again.
    private var lastKnownModel: FactorVIIIModel?
    private var lastKnownRealPercent: Double?

    init(repository: AppRepository? = nil, notifications: NotificationScheduling = NotificationService()) {
        self.repository = repository
        self.notifications = notifications
        self.settings = repository?.state.alertSettings ?? AlertSettings()
    }

    func refreshAuthorization() async {
        authorization = await notifications.authorizationStatus()
    }

    // MARK: - Settings

    /// Turning reminders on is the moment permission is requested — not at launch,
    /// so the prompt arrives when the user has just shown they want notifications.
    func setRemindersEnabled(_ enabled: Bool) async {
        if enabled {
            if await notifications.authorizationStatus() == .notDetermined {
                _ = await notifications.requestAuthorization()
            }
            await refreshAuthorization()
            // Refused: don't flip the switch on, or the UI would promise something
            // that can never be delivered.
            guard authorization == .authorized else {
                await applySettings { $0.remindersEnabled = false }
                return
            }
        }
        await applySettings { $0.remindersEnabled = enabled }
    }

    func setThreshold(_ percent: Double) async {
        await applySettings { $0.crossingThresholdPercent = percent }
    }

    func setLeadTime(hours: Double) async {
        await applySettings { $0.leadTimeHours = hours }
    }

    func setMissedDoseFollowUp(enabled: Bool) async {
        await applySettings { $0.missedDoseFollowUpEnabled = enabled }
    }

    func setMissedDoseFollowUp(hours: Double) async {
        await applySettings { $0.missedDoseFollowUpHours = hours }
    }

    private func applySettings(_ transform: (inout AlertSettings) -> Void) async {
        transform(&settings)
        persist()
        await rescheduleFromLastKnownLevel()
    }

    // MARK: - Scheduling

    /// Recomputes and re-registers the pending alerts for the given level.
    /// Call whenever the level changes — a dose logged, edited or deleted.
    func refreshSchedule(model: FactorVIIIModel, currentRealPercent: Double) async {
        lastKnownModel = model
        lastKnownRealPercent = currentRealPercent

        let alerts = AlertSchedule.alerts(
            settings: settings,
            model: model,
            currentRealPercent: currentRealPercent
        )
        let identifiers = await notifications.reschedule(alerts)
        scheduled = alerts
        settings.scheduledAlertIdentifiers = identifiers
        persist()
    }

    private func rescheduleFromLastKnownLevel() async {
        guard let lastKnownModel, let lastKnownRealPercent else { return }
        await refreshSchedule(model: lastKnownModel, currentRealPercent: lastKnownRealPercent)
    }

    private func persist() {
        guard let repository else { return }
        let settings = settings
        repository.updateAlertSettings { $0 = settings }
    }
}
