//
//  InjectionChainTests.swift
//  HEMOnitorTests
//
//  Covers the injection chain: sorted insertion (including back-dating), editing
//  and deletion, all of which have to rebuild every event that follows the change.
//

import Testing
import Foundation
@testable import HEMOnitor

struct InjectionChainTests {

    // MARK: - Fixtures

    /// A fixed point in the past, so no test depends on the wall clock.
    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    private func date(_ hoursFromBase: Double) -> Date {
        base.addingTimeInterval(hoursFromBase * 3600)
    }

    /// Default settings are 65 kg / 2 % baseline / 19 h half-life / 2.0 recovery,
    /// which makes the arithmetic exact for the doses used below:
    /// 1300 IU → +40 pp, 650 IU → +20 pp, and a 19 h gap halves the infused part.
    private func makeViewModel() -> FactorTrackerViewModel {
        FactorTrackerViewModel(settings: .defaultSettings)
    }

    private func isClose(_ a: Double, _ b: Double, _ tolerance: Double = 1e-9) -> Bool {
        abs(a - b) < tolerance
    }

    // MARK: - Chronological behaviour (regression guard)

    /// The pre-existing append-only path must still produce the same numbers it did
    /// before back-dating was introduced.
    @Test func chronologicalAddsProduceTheExpectedChain() {
        let viewModel = makeViewModel()

        viewModel.addInjection(doseIU: 1300, at: date(0))
        viewModel.addInjection(doseIU: 1300, at: date(19))

        #expect(viewModel.injections.count == 2)

        // First dose starts from baseline: 2 + 40 = 42
        #expect(isClose(viewModel.injections[0].realLevelBefore, 2))
        #expect(isClose(viewModel.injections[0].peakRealPercent, 42))

        // One half-life later the infused 40 pp has halved: 2 + 20 = 22, then +40 = 62
        #expect(isClose(viewModel.injections[1].realLevelBefore, 22))
        #expect(isClose(viewModel.injections[1].peakRealPercent, 62))
    }

    @Test func currentLevelDecaysFromTheMostRecentInjection() {
        let viewModel = makeViewModel()
        viewModel.addInjection(doseIU: 1300, at: date(0))

        viewModel.recalculateLevels(at: date(19))
        #expect(isClose(viewModel.currentRealLevelPercent, 22))

        viewModel.recalculateLevels(at: date(38))
        #expect(isClose(viewModel.currentRealLevelPercent, 12))
    }

    // MARK: - Back-dated insertion

    @Test func backdatedInsertKeepsTheArraySorted() {
        let viewModel = makeViewModel()

        viewModel.addInjection(doseIU: 1300, at: date(38))
        viewModel.addInjection(doseIU: 1300, at: date(0))
        viewModel.addInjection(doseIU: 1300, at: date(19))

        let dates = viewModel.injections.map(\.date)
        #expect(dates == [date(0), date(19), date(38)])
    }

    /// Inserting before every existing event: the new event anchors to baseline and
    /// everything after it has to be rebuilt on top of it.
    @Test func insertBeforeFirstEventAnchorsToBaselineAndShiftsTheTail() {
        let viewModel = makeViewModel()
        viewModel.addInjection(doseIU: 1300, at: date(19))

        // Before the insert, the lone event starts from baseline.
        #expect(isClose(viewModel.injections[0].realLevelBefore, 2))
        #expect(isClose(viewModel.injections[0].peakRealPercent, 42))

        viewModel.addInjection(doseIU: 1300, at: date(0))

        // The new first event is the one anchored to baseline now...
        #expect(isClose(viewModel.injections[0].realLevelBefore, 2))
        #expect(isClose(viewModel.injections[0].peakRealPercent, 42))
        // ...and the original event sits on top of its decayed remainder.
        #expect(isClose(viewModel.injections[1].realLevelBefore, 22))
        #expect(isClose(viewModel.injections[1].peakRealPercent, 62))
    }

    @Test func insertInTheMiddleRebuildsOnlyTheFollowingEvents() {
        let viewModel = makeViewModel()
        viewModel.addInjection(doseIU: 1300, at: date(0))
        viewModel.addInjection(doseIU: 1300, at: date(38))

        let firstBefore = viewModel.injections[0]

        viewModel.addInjection(doseIU: 650, at: date(19))

        // The event before the insertion point is untouched.
        #expect(viewModel.injections[0] == firstBefore)

        // Inserted: 2 + (42-2)*0.5 = 22, +20 → 42
        #expect(isClose(viewModel.injections[1].realLevelBefore, 22))
        #expect(isClose(viewModel.injections[1].peakRealPercent, 42))

        // Last event rebuilt on top of the inserted one: 2 + (42-2)*0.5 = 22, +40 → 62
        #expect(isClose(viewModel.injections[2].realLevelBefore, 22))
        #expect(isClose(viewModel.injections[2].peakRealPercent, 62))
    }

    /// The strongest guarantee back-dating can offer: the resulting chain depends
    /// only on the set of injections, never on the order they were entered in.
    @Test func chainIsIndependentOfInsertionOrder() {
        let entries: [(hours: Double, dose: Double)] = [
            (0, 1300), (19, 650), (38, 2000), (50, 900)
        ]

        let chronological = makeViewModel()
        for entry in entries {
            chronological.addInjection(doseIU: entry.dose, at: date(entry.hours))
        }

        let scrambled = makeViewModel()
        for entry in [entries[2], entries[0], entries[3], entries[1]] {
            scrambled.addInjection(doseIU: entry.dose, at: date(entry.hours))
        }

        #expect(chronological.injections.count == scrambled.injections.count)
        for (expected, actual) in zip(chronological.injections, scrambled.injections) {
            #expect(expected.date == actual.date)
            #expect(expected.doseIU == actual.doseIU)
            #expect(isClose(expected.realLevelBefore, actual.realLevelBefore))
            #expect(isClose(expected.peakRealPercent, actual.peakRealPercent))
        }
    }

    /// Two doses at the same instant: the later-entered one sorts after the earlier
    /// one, and with no time between them the second stacks on the first's full peak.
    @Test func sameTimestampInsertsAreStableAndStackWithoutDecay() {
        let viewModel = makeViewModel()

        viewModel.addInjection(doseIU: 1300, at: date(0))
        viewModel.addInjection(doseIU: 650, at: date(0))

        #expect(viewModel.injections.count == 2)
        // Insertion order is preserved for identical timestamps.
        #expect(viewModel.injections[0].doseIU == 1300)
        #expect(viewModel.injections[1].doseIU == 650)

        // No elapsed time, so no decay between them: 2 + 40 = 42, then 42 + 20 = 62
        #expect(isClose(viewModel.injections[0].peakRealPercent, 42))
        #expect(isClose(viewModel.injections[1].realLevelBefore, 42))
        #expect(isClose(viewModel.injections[1].peakRealPercent, 62))
    }

    // MARK: - Deletion

    @Test func deletingAMiddleEventRebuildsTheChainAsIfItNeverExisted() {
        let viewModel = makeViewModel()
        viewModel.addInjection(doseIU: 1300, at: date(0))
        viewModel.addInjection(doseIU: 650, at: date(19))
        viewModel.addInjection(doseIU: 1300, at: date(38))

        viewModel.deleteInjection(id: viewModel.injections[1].id)

        #expect(viewModel.injections.count == 2)

        // Identical to a chain that only ever had the two surviving doses.
        let reference = makeViewModel()
        reference.addInjection(doseIU: 1300, at: date(0))
        reference.addInjection(doseIU: 1300, at: date(38))

        for (expected, actual) in zip(reference.injections, viewModel.injections) {
            #expect(isClose(expected.realLevelBefore, actual.realLevelBefore))
            #expect(isClose(expected.peakRealPercent, actual.peakRealPercent))
        }
    }

    @Test func deletingTheLastEventLeavesEarlierOnesUntouched() {
        let viewModel = makeViewModel()
        viewModel.addInjection(doseIU: 1300, at: date(0))
        viewModel.addInjection(doseIU: 1300, at: date(19))

        let firstBefore = viewModel.injections[0]
        viewModel.deleteInjection(id: viewModel.injections[1].id)

        #expect(viewModel.injections.count == 1)
        #expect(viewModel.injections[0] == firstBefore)

        viewModel.recalculateLevels(at: date(19))
        #expect(isClose(viewModel.currentRealLevelPercent, 22))
    }

    @Test func deletingTheOnlyEventReturnsToBaseline() {
        let viewModel = makeViewModel()
        viewModel.addInjection(doseIU: 1300, at: date(0))

        viewModel.deleteInjection(id: viewModel.injections[0].id)

        #expect(viewModel.injections.isEmpty)
        #expect(isClose(viewModel.currentRealLevelPercent, 2))
    }

    @Test func deletingAnUnknownIdChangesNothing() {
        let viewModel = makeViewModel()
        viewModel.addInjection(doseIU: 1300, at: date(0))
        let before = viewModel.injections

        viewModel.deleteInjection(id: UUID())

        #expect(viewModel.injections == before)
    }

    // MARK: - Editing

    @Test func editingADoseRebuildsTheFollowingEvents() {
        let viewModel = makeViewModel()
        viewModel.addInjection(doseIU: 650, at: date(0))
        viewModel.addInjection(doseIU: 1300, at: date(19))

        viewModel.updateInjection(id: viewModel.injections[0].id, doseIU: 1300)

        // Corrected first dose: 2 + 40 = 42
        #expect(isClose(viewModel.injections[0].peakRealPercent, 42))
        // And the second event now sits on the larger remainder: 22 + 40 = 62
        #expect(isClose(viewModel.injections[1].realLevelBefore, 22))
        #expect(isClose(viewModel.injections[1].peakRealPercent, 62))
    }

    @Test func redatingAnEventEarlierReordersAndRebuilds() {
        let viewModel = makeViewModel()
        viewModel.addInjection(doseIU: 1300, at: date(0))
        viewModel.addInjection(doseIU: 650, at: date(38))

        // Move the later event to before the first one.
        let movedId = viewModel.injections[1].id
        viewModel.updateInjection(id: movedId, date: date(-19))

        #expect(viewModel.injections.map(\.date) == [date(-19), date(0)])
        #expect(viewModel.injections[0].id == movedId)

        // Same chain as entering them in that order from scratch.
        let reference = makeViewModel()
        reference.addInjection(doseIU: 650, at: date(-19))
        reference.addInjection(doseIU: 1300, at: date(0))

        for (expected, actual) in zip(reference.injections, viewModel.injections) {
            #expect(isClose(expected.realLevelBefore, actual.realLevelBefore))
            #expect(isClose(expected.peakRealPercent, actual.peakRealPercent))
        }
    }

    @Test func redatingAnEventLaterReordersAndRebuilds() {
        let viewModel = makeViewModel()
        viewModel.addInjection(doseIU: 1300, at: date(0))
        viewModel.addInjection(doseIU: 650, at: date(19))

        // Move the first event to after the second.
        let movedId = viewModel.injections[0].id
        viewModel.updateInjection(id: movedId, date: date(38))

        #expect(viewModel.injections.map(\.date) == [date(19), date(38)])
        #expect(viewModel.injections[1].id == movedId)

        let reference = makeViewModel()
        reference.addInjection(doseIU: 650, at: date(19))
        reference.addInjection(doseIU: 1300, at: date(38))

        for (expected, actual) in zip(reference.injections, viewModel.injections) {
            #expect(isClose(expected.realLevelBefore, actual.realLevelBefore))
            #expect(isClose(expected.peakRealPercent, actual.peakRealPercent))
        }
    }

    @Test func editingPreservesTheEventIdentity() {
        let viewModel = makeViewModel()
        viewModel.addInjection(doseIU: 650, at: date(0))
        let id = viewModel.injections[0].id

        viewModel.updateInjection(id: id, doseIU: 1300, date: date(5))

        #expect(viewModel.injections.count == 1)
        #expect(viewModel.injections[0].id == id)
        #expect(viewModel.injections[0].doseIU == 1300)
        #expect(viewModel.injections[0].date == date(5))
    }

    @Test func editingAnUnknownIdChangesNothing() {
        let viewModel = makeViewModel()
        viewModel.addInjection(doseIU: 1300, at: date(0))
        let before = viewModel.injections

        viewModel.updateInjection(id: UUID(), doseIU: 9999)

        #expect(viewModel.injections == before)
    }

    // MARK: - Real vs. display separation

    /// The chain is stored entirely in real space; calibration only scales what's
    /// read out of it. Editing the chain must not bake the factor into stored values.
    @Test func storedChainStaysRealWhileDisplayScales() {
        let viewModel = makeViewModel()
        viewModel.addInjection(doseIU: 1300, at: date(0))
        viewModel.addInjection(doseIU: 1300, at: date(19))

        // Halve everything on display.
        viewModel.model.calibrationFactor = 0.5

        // Stored values are untouched by calibration...
        #expect(isClose(viewModel.injections[1].peakRealPercent, 62))

        // ...while the display level is scaled from them.
        viewModel.recalculateLevels(at: date(19))
        #expect(isClose(viewModel.currentRealLevelPercent, 62))
        #expect(isClose(viewModel.currentDisplayLevelPercent, 31))

        // A back-dated insert with calibration active still stores real values.
        viewModel.addInjection(doseIU: 650, at: date(10))
        for event in viewModel.injections {
            #expect(event.realLevelBefore >= viewModel.model.baselinePercent)
        }
        #expect(isClose(viewModel.injections[0].peakRealPercent, 42))
    }

    // MARK: - Future-dated entries

    /// A future-dated injection must not pull the *current* level up to its peak.
    @Test func futureDatedInjectionDoesNotAffectTheCurrentLevel() {
        let viewModel = makeViewModel()
        viewModel.addInjection(doseIU: 1300, at: date(0))
        viewModel.addInjection(doseIU: 1300, at: date(100))

        // Asked about a moment between the two, only the first has happened.
        viewModel.recalculateLevels(at: date(19))
        #expect(isClose(viewModel.currentRealLevelPercent, 22))

        // Asked about a moment before either, the level is baseline.
        viewModel.recalculateLevels(at: date(-1))
        #expect(isClose(viewModel.currentRealLevelPercent, 2))
    }

    // MARK: - Persistence

    @Test func chainEditsPersist() {
        let store = InMemoryPersistenceStore()
        let viewModel = FactorTrackerViewModel(repository: AppRepository(store: store))

        viewModel.addInjection(doseIU: 1300, at: date(19))
        viewModel.addInjection(doseIU: 1300, at: date(0))   // back-dated
        viewModel.addInjection(doseIU: 650, at: date(38))
        viewModel.deleteInjection(id: viewModel.injections[2].id)
        viewModel.updateInjection(id: viewModel.injections[1].id, doseIU: 2000)

        let reloaded = FactorTrackerViewModel(repository: AppRepository(store: store))

        #expect(reloaded.injections.count == 2)
        #expect(reloaded.injections.map(\.date) == [date(0), date(19)])
        #expect(reloaded.injections[1].doseIU == 2000)
        for (expected, actual) in zip(viewModel.injections, reloaded.injections) {
            #expect(expected == actual)
        }
    }
}
