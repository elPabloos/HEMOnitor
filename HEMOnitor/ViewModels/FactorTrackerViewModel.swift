import Foundation
import Combine

final class FactorTrackerViewModel: ObservableObject {
    /// Modelul farmacocinetic și parametrii pacientului
    @Published var model: FactorVIIIModel
    
    /// Istoricul injecțiilor
    @Published private(set) var injections: [InjectionEvent] = []
    
    /// Nivelul curent REAL (necalibrat), în procente
    @Published private(set) var currentRealLevelPercent: Double
    
    /// Nivelul curent de AFIȘAT (după aplicarea calibrationFactor), în procente
    @Published private(set) var currentDisplayLevelPercent: Double

    /// Dacă e prezent, injecțiile și parametrii de calibrare se persistă prin el.
    /// Nil pentru previews/teste care nu au nevoie de persistență pe disc.
    private let repository: AppRepository?

    // MARK: - Inițializare
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

    /// Inițializare susținută de persistență: încarcă parametrii pacientului și
    /// istoricul injecțiilor salvate de `repository`, apoi persistă orice
    /// modificare ulterioară a injecțiilor/calibrării prin el.
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

    // MARK: - Persistență

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

    // MARK: - Recalculare niveluri
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
    
    // MARK: - Injecții
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

    // MARK: - Resetare totală (șterge istoricul și revine la baseline)
    func resetAll() {
        injections.removeAll()
        currentRealLevelPercent = model.baselinePercent
        currentDisplayLevelPercent = model.displayLevel(fromRealPercent: model.baselinePercent)
        persistInjections()
    }
}

extension FactorTrackerViewModel {
    // MARK: - Calibrare (A: factor de afișare)
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
    
    // MARK: - Calibrare (B: recovery)
    /// Ajustează recovery astfel încât nivelul REAL prezis să corespundă observației.
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
