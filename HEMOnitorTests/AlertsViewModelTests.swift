//
//  AlertsViewModelTests.swift
//  HEMOnitorTests
//

import Testing
import Foundation
@testable import HEMOnitor

/// Stands in for iOS so permission and scheduling behaviour can be exercised.
private actor FakeNotificationScheduler: NotificationScheduling {
    var status: NotificationAuthorization
    var grantOnRequest: Bool
    private(set) var scheduledBatches: [[ScheduledAlert]] = []
    private(set) var cancelCount = 0
    private(set) var requestCount = 0

    init(status: NotificationAuthorization = .notDetermined, grantOnRequest: Bool = true) {
        self.status = status
        self.grantOnRequest = grantOnRequest
    }

    func authorizationStatus() async -> NotificationAuthorization { status }

    func requestAuthorization() async -> Bool {
        requestCount += 1
        status = grantOnRequest ? .authorized : .denied
        return grantOnRequest
    }

    @discardableResult
    func reschedule(_ alerts: [ScheduledAlert]) async -> [String] {
        scheduledBatches.append(alerts)
        return status == .authorized ? alerts.map(\.id) : []
    }

    func cancelAll() async { cancelCount += 1 }

    var lastBatch: [ScheduledAlert] { scheduledBatches.last ?? [] }
}

@MainActor
struct AlertsViewModelTests {

    private func model() -> FactorVIIIModel {
        FactorVIIIModel(weightKg: 65, baselinePercent: 2, halfLifeHours: 19)
    }

    @Test func enablingRemindersAsksForPermissionOnce() async {
        let fake = FakeNotificationScheduler(status: .notDetermined, grantOnRequest: true)
        let viewModel = AlertsViewModel(notifications: fake)

        await viewModel.setRemindersEnabled(true)

        #expect(await fake.requestCount == 1)
        #expect(viewModel.settings.remindersEnabled)
        #expect(viewModel.authorization == .authorized)
    }

    /// If the user refuses, the toggle must not stay on — otherwise the screen
    /// promises alerts that can never arrive.
    @Test func refusedPermissionLeavesRemindersOff() async {
        let fake = FakeNotificationScheduler(status: .notDetermined, grantOnRequest: false)
        let viewModel = AlertsViewModel(notifications: fake)

        await viewModel.setRemindersEnabled(true)

        #expect(viewModel.settings.remindersEnabled == false)
        #expect(viewModel.authorization == .denied)
    }

    @Test func schedulingReflectsTheCurrentLevel() async {
        let fake = FakeNotificationScheduler(status: .authorized)
        let viewModel = AlertsViewModel(notifications: fake)
        await viewModel.setRemindersEnabled(true)

        await viewModel.refreshSchedule(model: model(), currentRealPercent: 42)
        #expect(viewModel.scheduled.contains { $0.kind == .crossing })

        // Already below the threshold — nothing left to warn about.
        await viewModel.refreshSchedule(model: model(), currentRealPercent: 5)
        #expect(viewModel.scheduled.isEmpty)
    }

    /// Changing a setting must re-register the notifications, not just the stored value.
    @Test func changingASettingReschedules() async {
        let fake = FakeNotificationScheduler(status: .authorized)
        let viewModel = AlertsViewModel(notifications: fake)
        await viewModel.setRemindersEnabled(true)
        await viewModel.refreshSchedule(model: model(), currentRealPercent: 42)

        let before = await fake.scheduledBatches.count
        await viewModel.setThreshold(30)
        let after = await fake.scheduledBatches.count

        #expect(after > before)
        #expect(viewModel.settings.crossingThresholdPercent == 30)
    }

    @Test func settingsPersistAndReload() async {
        let store = InMemoryPersistenceStore()
        let fake = FakeNotificationScheduler(status: .authorized)
        let viewModel = AlertsViewModel(repository: AppRepository(store: store), notifications: fake)

        await viewModel.setRemindersEnabled(true)
        await viewModel.setThreshold(25)
        await viewModel.setMissedDoseFollowUp(enabled: true)

        let reloaded = AlertsViewModel(repository: AppRepository(store: store), notifications: fake)
        #expect(reloaded.settings.remindersEnabled)
        #expect(reloaded.settings.crossingThresholdPercent == 25)
        #expect(reloaded.settings.missedDoseFollowUpEnabled)
    }
}
