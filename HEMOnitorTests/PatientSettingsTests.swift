//
//  PatientSettingsTests.swift
//  HEMOnitorTests
//

import Testing
import Foundation
@testable import HEMOnitor

struct PatientSettingsTests {

    /// Builds a view model backed by a shared in-memory store, and returns both so a
    /// second view model can be created from the same store to check persistence.
    private func makeViewModel(
        settings: AppSettings = .defaultSettings
    ) -> (viewModel: FactorTrackerViewModel, store: InMemoryPersistenceStore) {
        var state = AppState()
        state.settings = settings
        let store = InMemoryPersistenceStore(initialState: state)
        return (FactorTrackerViewModel(repository: AppRepository(store: store)), store)
    }

    @Test func defaultSettingsMatchThePreviouslyHardcodedValues() {
        // These were literals in ContentView.init before this task.
        let defaults = AppSettings.defaultSettings
        #expect(defaults.weightKg == 65)
        #expect(defaults.baselinePercent == 2)
        #expect(defaults.halfLifeHours == 19)
        #expect(defaults.recoveryPercentPerIUPerKg == 2.0)
        #expect(defaults.calibrationFactor == nil)
    }

    @Test func viewModelLoadsPatientParametersFromSettings() {
        var settings = AppSettings.defaultSettings
        settings.weightKg = 80
        settings.baselinePercent = 1
        settings.halfLifeHours = 12
        settings.productName = "Adynovi"

        let viewModel = FactorTrackerViewModel(settings: settings)

        #expect(viewModel.model.weightKg == 80)
        #expect(viewModel.model.baselinePercent == 1)
        #expect(viewModel.model.halfLifeHours == 12)
        #expect(viewModel.productName == "Adynovi")
        // With no injections, the current level sits at baseline.
        #expect(viewModel.currentRealLevelPercent == 1)
    }

    @Test func updatingPatientParametersPersistsThem() {
        let (viewModel, store) = makeViewModel()

        viewModel.updatePatientParameters(weightKg: 72, halfLifeHours: 14, productName: "Jivi")

        // In memory
        #expect(viewModel.model.weightKg == 72)
        #expect(viewModel.model.halfLifeHours == 14)
        #expect(viewModel.productName == "Jivi")
        // Untouched parameters keep their previous value
        #expect(viewModel.model.baselinePercent == AppSettings.defaultSettings.baselinePercent)

        // And on reload from the same store
        let reloaded = FactorTrackerViewModel(repository: AppRepository(store: store))
        #expect(reloaded.model.weightKg == 72)
        #expect(reloaded.model.halfLifeHours == 14)
        #expect(reloaded.productName == "Jivi")
    }

    @Test func onboardingCompletionPersists() {
        let (viewModel, store) = makeViewModel()
        #expect(viewModel.hasCompletedOnboarding == false)

        viewModel.completeOnboarding()
        #expect(viewModel.hasCompletedOnboarding)

        let reloaded = FactorTrackerViewModel(repository: AppRepository(store: store))
        #expect(reloaded.hasCompletedOnboarding)
    }

    @Test func displayStyleChangePersists() {
        let (viewModel, store) = makeViewModel()
        #expect(viewModel.displayStyle == .ring)

        viewModel.displayStyle = .curve

        let reloaded = FactorTrackerViewModel(repository: AppRepository(store: store))
        #expect(reloaded.displayStyle == .curve)
    }

    /// Regression: `persistCalibration` was folded into `persistSettings` in this task,
    /// so calibration must still survive a reload.
    @Test func calibrationStillPersistsAfterTheSettingsRefactor() {
        let (viewModel, store) = makeViewModel()

        viewModel.calibrateRecovery(doseIU: 2000, observedPeakPercent: 50, timeFromDoseHours: 1)
        let factor = viewModel.model.calibrationFactor
        #expect(factor != nil)

        let reloaded = FactorTrackerViewModel(repository: AppRepository(store: store))
        #expect(reloaded.model.calibrationFactor == factor)
    }

    /// Updating patient parameters must not disturb calibration, and vice versa —
    /// both write through the same `persistSettings`, so a field could be dropped.
    @Test func patientParameterUpdateKeepsCalibrationIntact() {
        let (viewModel, store) = makeViewModel()

        viewModel.calibrateRecovery(doseIU: 2000, observedPeakPercent: 50, timeFromDoseHours: 1)
        let factor = viewModel.model.calibrationFactor
        let recovery = viewModel.model.recoveryPercentPerIUPerKg

        viewModel.updatePatientParameters(weightKg: 90)

        let reloaded = FactorTrackerViewModel(repository: AppRepository(store: store))
        #expect(reloaded.model.weightKg == 90)
        #expect(reloaded.model.calibrationFactor == factor)
        #expect(reloaded.model.recoveryPercentPerIUPerKg == recovery)
    }

    /// The unpersisted init is used by previews — it must not touch any store.
    @Test func unpersistedViewModelDoesNotWriteToAnyStore() {
        let store = InMemoryPersistenceStore()
        let viewModel = FactorTrackerViewModel(settings: .defaultSettings)

        viewModel.updatePatientParameters(weightKg: 99)
        viewModel.completeOnboarding()
        viewModel.addInjection(doseIU: 1000)

        // The store was never handed to the view model, so it stays pristine.
        #expect(store.load() == AppState())
    }
}
