//
//  OnboardingModelsTests.swift
//  HEMOnitorTests
//

import Testing
@testable import HEMOnitor

struct OnboardingModelsTests {

    // MARK: - BaselineTier

    @Test func baselineTierRepresentativeValuesFallWithinTheirRange() {
        #expect(BaselineTier.severe.representativeValue < 1)
        #expect((1...5).contains(BaselineTier.moderate.representativeValue))
        #expect(BaselineTier.mild.representativeValue > 5)
    }

    @Test func closestMapsBoundaryValuesToTheExpectedTier() {
        #expect(BaselineTier.closest(to: 0.5) == .severe)
        #expect(BaselineTier.closest(to: 0.99) == .severe)
        #expect(BaselineTier.closest(to: 1) == .moderate)
        #expect(BaselineTier.closest(to: 5) == .moderate)
        #expect(BaselineTier.closest(to: 5.01) == .mild)
        #expect(BaselineTier.closest(to: 20) == .mild)
    }

    /// The app's hardcoded default (2%, from `AppSettings.defaultSettings`) must
    /// land in the moderate tier, so re-opening onboarding with default settings
    /// doesn't silently jump to a different severity than what's actually stored.
    @Test func defaultSettingsBaselineMapsToModerate() {
        #expect(BaselineTier.closest(to: AppSettings.defaultSettings.baselinePercent) == .moderate)
    }

    // MARK: - OnboardingProduct

    @Test func catalogueHasNoDuplicateIDsAndIncludesOther() {
        let ids = OnboardingProduct.catalogue.map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(ids.contains("other"))
    }

    @Test func catalogueHalfLivesMatchKnownProducts() {
        // These mirror the app's own defaults/constants (Elocta's 19h is the
        // hardcoded default in AppSettings.defaultSettings) and common label values
        // for the others — sanity checks against typos, not clinical claims.
        let byID = Dictionary(uniqueKeysWithValues: OnboardingProduct.catalogue.map { ($0.id, $0) })
        #expect(byID["elocta"]?.halfLifeHours == 19)
        #expect(byID["adynovi"]?.halfLifeHours == 15)
        #expect(byID["advate"]?.halfLifeHours == 12)
    }

    @Test func matchingFallsBackToOtherForUnknownProductNames() {
        #expect(OnboardingProduct.matching(productName: "Elocta").id == "elocta")
        #expect(OnboardingProduct.matching(productName: "Some Unlisted Product").id == "other")
    }
}
