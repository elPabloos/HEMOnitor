import Foundation
import Combine

final class FactorTrackerViewModel: ObservableObject {
    /// The pharmacokinetic model and patient parameters
    @Published var model: FactorVIIIModel

    /// The injection history
    @Published private(set) var injections: [InjectionEvent] = []

    /// The current REAL (uncalibrated) level, in percent
    @Published private(set) var currentRealLevelPercent: Double

    /// The current DISPLAY level (after applying calibrationFactor), in percent
    @Published private(set) var currentDisplayLevelPercent: Double

    /// The factor product these parameters describe (e.g. "Elocta"). Purely
    /// descriptive — the half-life it implies already lives on `model`.
    @Published private(set) var productName: String

    /// Whether the onboarding wizard has been completed. Gates the app root.
    @Published private(set) var hasCompletedOnboarding: Bool

    /// How the current level is rendered on the main screen.
    @Published var displayStyle: DisplayStyle {
        didSet { persistSettings() }
    }

    /// When present, injections, patient parameters and preferences are persisted
    /// through it. Nil for previews/tests that don't need on-disk persistence.
    private let repository: AppRepository?

    // MARK: - Initialization

    /// In-memory initialization from an explicit settings snapshot — for previews
    /// and tests. Nothing is persisted.
    convenience init(settings: AppSettings = .defaultSettings) {
        self.init(settings: settings, repository: nil)
    }

    /// Persistence-backed initialization: loads patient parameters, preferences
    /// and the injection history saved by `repository`, then persists any further
    /// change through it.
    convenience init(repository: AppRepository) {
        self.init(settings: repository.state.settings, repository: repository)
    }

    private init(settings: AppSettings, repository: AppRepository?) {
        self.repository = repository
        self.model = FactorVIIIModel(
            weightKg: settings.weightKg,
            baselinePercent: settings.baselinePercent,
            halfLifeHours: settings.halfLifeHours,
            recoveryPercentPerIUPerKg: settings.recoveryPercentPerIUPerKg,
            calibrationFactor: settings.calibrationFactor
        )
        self.productName = settings.productName
        self.hasCompletedOnboarding = settings.hasCompletedOnboarding
        self.displayStyle = settings.displayStyle
        self.injections = repository?.state.injections ?? []
        self.currentRealLevelPercent = settings.baselinePercent
        self.currentDisplayLevelPercent = settings.baselinePercent
        recalculateLevels()
    }

    // MARK: - Patient parameters

    /// Updates the patient parameters and persists them. The PK fields live on
    /// `model`, which stays their single source of truth — `AppSettings` is
    /// written from it, never the other way round (outside of init).
    func updatePatientParameters(
        weightKg: Double? = nil,
        baselinePercent: Double? = nil,
        halfLifeHours: Double? = nil,
        productName: String? = nil
    ) {
        if let weightKg { model.weightKg = weightKg }
        if let baselinePercent { model.baselinePercent = baselinePercent }
        if let halfLifeHours { model.halfLifeHours = halfLifeHours }
        if let productName { self.productName = productName }
        recalculateLevels()
        persistSettings()
    }

    /// Marks onboarding as done, so the app root stops showing the wizard.
    func completeOnboarding() {
        hasCompletedOnboarding = true
        persistSettings()
    }

    // MARK: - Persistence

    private func persistInjections() {
        guard let repository else { return }
        let injections = injections
        repository.updateInjections { $0 = injections }
    }

    /// Projects the current in-memory state back onto the persisted `AppSettings`.
    /// Writes every field, so it's correct to call after any settings-affecting
    /// change (patient parameters, calibration, preferences).
    private func persistSettings() {
        guard let repository else { return }
        let model = model
        let productName = productName
        let hasCompletedOnboarding = hasCompletedOnboarding
        let displayStyle = displayStyle
        repository.updateSettings { settings in
            settings.weightKg = model.weightKg
            settings.baselinePercent = model.baselinePercent
            settings.halfLifeHours = model.halfLifeHours
            settings.recoveryPercentPerIUPerKg = model.recoveryPercentPerIUPerKg
            settings.calibrationFactor = model.calibrationFactor
            settings.productName = productName
            settings.hasCompletedOnboarding = hasCompletedOnboarding
            settings.displayStyle = displayStyle
        }
    }

    // MARK: - Level recalculation
    func recalculateLevels(at date: Date = Date()) {
        guard let last = injections.last else {
            currentRealLevelPercent = model.baselinePercent
            currentDisplayLevelPercent = model.displayLevel(fromRealPercent: currentRealLevelPercent)
            return
        }
        let hours = date.timeIntervalSince(last.peakDate) / 3600.0
        let real = model.levelAtTime(
            peakPercent: last.peakRealPercent,
            hoursSincePeak: max(0, hours)
        )
        currentRealLevelPercent = real
        currentDisplayLevelPercent = model.displayLevel(fromRealPercent: real)
    }
    
    // MARK: - Injections
    func addInjection(doseIU: Double, at date: Date = Date()) {
        recalculateLevels(at: date)
        let levelBefore = currentRealLevelPercent
        
        let peakReal = model.newPeakAfterAdditionalDose(
            doseIU: doseIU,
            currentRealLevelPercent: levelBefore
        )
        
        let event = InjectionEvent(
            id: UUID(),
            date: date,
            doseIU: doseIU,
            realLevelBefore: levelBefore,
            peakRealPercent: peakReal
        )
        injections.append(event)

        currentRealLevelPercent = peakReal
        currentDisplayLevelPercent = model.displayLevel(fromRealPercent: peakReal)
        persistInjections()
    }

    // MARK: - Full reset (clears history and returns to baseline)
    func resetAll() {
        injections.removeAll()
        currentRealLevelPercent = model.baselinePercent
        currentDisplayLevelPercent = model.displayLevel(fromRealPercent: model.baselinePercent)
        persistInjections()
    }
}

extension FactorTrackerViewModel {
    // MARK: - Calibration (A: display factor)
    func calibrateRecovery(
        doseIU: Double,
        observedPeakPercent: Double,
        timeFromDoseHours: Double = 0.5
    ) {
        model.calibrateRecovery(
            doseIU: doseIU,
            observedPeakPercent: observedPeakPercent,
            timeFromDoseHours: timeFromDoseHours
        )
        recalculateLevels()
        persistSettings()
    }
    
    // MARK: - Calibration (B: recovery)
    /// Adjusts recovery so the predicted REAL level matches the observation.
    func calibrateRecoveryParameter(
        doseIU: Double,
        observedDisplayPercent: Double,
        timeFromDoseHours: Double = 0.5
    ) {
        model.calibrateRecoveryParameter(
            doseIU: doseIU,
            observedDisplayPercent: observedDisplayPercent,
            timeFromDoseHours: timeFromDoseHours
        )
        recalculateLevels()
        persistSettings()
    }
}
