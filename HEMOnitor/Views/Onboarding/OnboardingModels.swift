//
//  OnboardingModels.swift
//  HEMOnitor
//

import Foundation

/// A clinically conventional FVIII severity tier, used by step 1 of onboarding
/// to pick a representative baseline percentage without asking for an exact lab
/// value the patient likely doesn't have on hand.
///
/// The three tiers and their cutoffs (<1% severe, 1–5% moderate, >5% mild) match
/// the standard hemophilia severity classification (WFH guidelines).
enum BaselineTier: CaseIterable, Identifiable {
    case severe
    case moderate
    case mild

    var id: Self { self }

    /// The percentage range shown on the selector button.
    var displayRange: String {
        switch self {
        case .severe: return "<1%"
        case .moderate: return "1–5%"
        case .mild: return ">5%"
        }
    }

    var label: String {
        switch self {
        case .severe: return "Severe"
        case .moderate: return "Moderate"
        case .mild: return "Mild"
        }
    }

    /// A single representative value stored as `baselinePercent`, chosen from the
    /// middle of each tier's range (0.5% for the open-ended severe tier).
    var representativeValue: Double {
        switch self {
        case .severe: return 0.5
        case .moderate: return 3
        case .mild: return 7
        }
    }

    /// Maps a stored baseline percentage back to the tier that produced it (or
    /// the closest one, for values that didn't originate from this picker) —
    /// used to pre-select a tier when onboarding re-opens with existing settings.
    static func closest(to percent: Double) -> BaselineTier {
        if percent < 1 {
            return .severe
        } else if percent <= 5 {
            return .moderate
        } else {
            return .mild
        }
    }
}

/// A factor VIII product offered in step 2 of onboarding, with the half-life
/// used to seed the patient's PK parameters.
struct OnboardingProduct: Identifiable, Equatable {
    let id: String
    let name: String
    let subtitle: String
    let halfLifeHours: Double

    /// A handful of real extended/standard half-life FVIII products, plus a
    /// generic fallback for anything not listed. Half-lives are population
    /// averages for tracking purposes only, not prescribing information —
    /// calibrating from a lab result (existing `CalibrationView`) personalizes
    /// this later.
    static let catalogue: [OnboardingProduct] = [
        OnboardingProduct(
            id: "elocta",
            name: "Elocta",
            subtitle: "Extended half-life FVIII (efmoroctocog alfa)",
            halfLifeHours: 19
        ),
        OnboardingProduct(
            id: "adynovi",
            name: "Adynovi",
            subtitle: "Extended half-life FVIII (rurioctocog alfa pegol)",
            halfLifeHours: 15
        ),
        OnboardingProduct(
            id: "advate",
            name: "Advate",
            subtitle: "Standard half-life FVIII (octocog alfa)",
            halfLifeHours: 12
        ),
        OnboardingProduct(
            id: "other",
            name: "Other",
            subtitle: "Not listed — uses a standard half-life estimate",
            halfLifeHours: 12
        )
    ]

    /// Looks up a catalogue entry by product name (as stored in `AppSettings.productName`),
    /// falling back to "Other" for anything not listed.
    static func matching(productName: String) -> OnboardingProduct {
        catalogue.first(where: { $0.name == productName }) ?? catalogue.last { $0.id == "other" }!
    }
}
