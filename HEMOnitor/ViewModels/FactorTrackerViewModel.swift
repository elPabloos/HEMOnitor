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

    /// When present, injections and calibration parameters are persisted through it.
    /// Nil for previews/tests that don't need on-disk persistence.
    private let repository: AppRepository?

    // MARK: - Initialization
    init(
        weightKg: Double,
        baselinePercent: Double,
        halfLifeHours: Double = 19.0
    ) {
        let model = FactorVIIIModel(
            weightKg: weightKg,
            baselinePercent: baselinePercent,
            halfLifeHours: halfLifeHours,
            recoveryPercentPerIUPerKg: 2.0,
            calibrationFactor: nil
        )
        self.model = model
        self.currentRealLevelPercent = baselinePercent
        self.currentDisplayLevelPercent = baselinePercent
        self.repository = nil
    }

    /// Persistence-backed initialization: loads patient parameters and the
    /// injection history saved by `repository`, then persists any further
    /// injection/calibration change through it.
    init(repository: AppRepository) {
        self.repository = repository
        let settings = repository.state.settings
        self.model = FactorVIIIModel(
            weightKg: settings.weightKg,
            baselinePercent: settings.baselinePercent,
            halfLifeHours: settings.halfLifeHours,
            recoveryPercentPerIUPerKg: settings.recoveryPercentPerIUPerKg,
            calibrationFactor: settings.calibrationFactor
        )
        self.injections = repository.state.injections
        self.currentRealLevelPercent = settings.baselinePercent
        self.currentDisplayLevelPercent = settings.baselinePercent
        recalculateLevels()
    }

    // MARK: - Persistence

    private func persistInjections() {
        guard let repository else { return }
        let injections = injections
        repository.updateInjections { $0 = injections }
    }

    private func persistCalibration() {
        guard let repository else { return }
        let recovery = model.recoveryPercentPerIUPerKg
        let calibrationFactor = model.calibrationFactor
        repository.updateSettings { settings in
            settings.recoveryPercentPerIUPerKg = recovery
            settings.calibrationFactor = calibrationFactor
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
        persistCalibration()
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
        persistCalibration()
    }
}
