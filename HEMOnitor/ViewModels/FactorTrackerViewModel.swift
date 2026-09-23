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

    /// Decays from the most recent injection at or before `date`.
    ///
    /// Note this is the last injection *at or before* `date`, not simply
    /// `injections.last`. With back-dating, `injections` stays sorted but may
    /// contain entries later than the date being asked about (a future-dated
    /// entry, or a backwards time simulation), and decaying from one of those
    /// would report a level that hasn't happened yet. When every entry is in the
    /// past — the only case that existed before back-dating — this picks
    /// `injections.last` and behaves exactly as it did before.
    func recalculateLevels(at date: Date = Date()) {
        guard let last = injections.last(where: { $0.date <= date }) else {
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

    /// `injections` is kept sorted ascending by date. This returns where an event
    /// dated `date` belongs; searching for the first strictly-later entry means an
    /// event lands *after* any existing entries sharing its timestamp, which gives
    /// same-instant doses a stable, insertion-ordered sequence.
    private func insertionIndex(for date: Date) -> Int {
        injections.firstIndex(where: { $0.date > date }) ?? injections.count
    }

    /// Recomputes `realLevelBefore`/`peakRealPercent` for every event from `index`
    /// onward, then refreshes the current level.
    ///
    /// Each event's peak is built on the level left behind by the one before it, so
    /// inserting, re-dating or removing an event invalidates the whole tail of the
    /// chain. Events before `index` are untouched — they can't be affected by a
    /// change that happens after them. Each event keeps its `id`, so SwiftUI
    /// identity survives the rewrite.
    private func recomputeChain(fromIndex index: Int) {
        guard index < injections.count else {
            // Nothing after the change (e.g. the last event was deleted).
            recalculateLevels()
            return
        }

        for i in max(0, index)..<injections.count {
            let event = injections[i]

            let realLevelBefore: Double
            if i == 0 {
                realLevelBefore = model.baselinePercent
            } else {
                let previous = injections[i - 1]
                let hours = event.date.timeIntervalSince(previous.peakDate) / 3600.0
                realLevelBefore = model.levelAtTime(
                    peakPercent: previous.peakRealPercent,
                    hoursSincePeak: max(0, hours)
                )
            }

            injections[i] = InjectionEvent(
                id: event.id,
                date: event.date,
                doseIU: event.doseIU,
                realLevelBefore: realLevelBefore,
                peakRealPercent: model.newPeakAfterAdditionalDose(
                    doseIU: event.doseIU,
                    currentRealLevelPercent: realLevelBefore
                ),
                lot: event.lot,
                productName: event.productName
            )
        }

        recalculateLevels()
    }

    /// Records an injection. `date` may be in the past: the event is spliced into
    /// chronological position and every later event is recomputed on top of it.
    ///
    /// `lot` and `productName` are provenance only — they never affect the chain, and
    /// are carried through rebuilds untouched.
    func addInjection(
        doseIU: Double,
        at date: Date = Date(),
        lot: String? = nil,
        productName: String? = nil
    ) {
        let index = insertionIndex(for: date)
        injections.insert(
            InjectionEvent(
                id: UUID(),
                date: date,
                doseIU: doseIU,
                // Placeholders; recomputeChain fills in the real values below.
                realLevelBefore: model.baselinePercent,
                peakRealPercent: model.baselinePercent,
                lot: lot,
                productName: productName
            ),
            at: index
        )
        recomputeChain(fromIndex: index)
        persistInjections()
    }

    /// Changes an existing injection's dose and/or date. Re-dating moves it to its
    /// new chronological position and recomputes from whichever position comes
    /// first, so both the old and new neighbourhoods are corrected.
    func updateInjection(id: UUID, doseIU: Double? = nil, date: Date? = nil) {
        guard let oldIndex = injections.firstIndex(where: { $0.id == id }) else { return }
        let existing = injections[oldIndex]

        injections.remove(at: oldIndex)
        let newDate = date ?? existing.date
        let newIndex = insertionIndex(for: newDate)
        injections.insert(
            InjectionEvent(
                id: existing.id,
                date: newDate,
                doseIU: doseIU ?? existing.doseIU,
                // Placeholders; recomputeChain fills in the real values below.
                realLevelBefore: model.baselinePercent,
                peakRealPercent: model.baselinePercent,
                // Provenance survives an edit — re-dating a dose doesn't change which
                // vial it came from.
                lot: existing.lot,
                productName: existing.productName
            ),
            at: newIndex
        )

        recomputeChain(fromIndex: min(oldIndex, newIndex))
        persistInjections()
    }

    /// Removes an injection and recomputes every event that followed it.
    func deleteInjection(id: UUID) {
        guard let index = injections.firstIndex(where: { $0.id == id }) else { return }
        injections.remove(at: index)
        recomputeChain(fromIndex: index)
        persistInjections()
    }

    /// Mean IU consumed per day across a trailing window, or nil when there is no
    /// history in it. Divides by the full window rather than by the number of doses,
    /// so a patient dosing twice a week averages correctly rather than looking like
    /// they consume a full dose daily. `now` is injectable so this is testable.
    func averageDailyDoseIU(overLastDays days: Int = 30, now: Date = Date()) -> Double? {
        guard days > 0 else { return nil }
        let cutoff = now.addingTimeInterval(-Double(days) * 86_400)
        let recent = injections.filter { $0.date >= cutoff && $0.date <= now }
        guard !recent.isEmpty else { return nil }
        return recent.reduce(0) { $0 + $1.doseIU } / Double(days)
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
