//
//  NumberFormatting.swift
//  HEMOnitor
//

import Foundation

/// Whole-number rendering for doses, percentages and IU totals.
///
/// **Why this exists.** `Text("\(Int(dose)) IU")` looks harmless but is a trap:
/// that string literal is a `LocalizedStringKey`, so SwiftUI formats the
/// interpolated integer through the current locale — which inserts a grouping
/// separator. In a locale that groups with "." a 3000 IU dose renders as
/// **"3.000 IU"**, i.e. three. For a dose of clotting factor that is not a cosmetic
/// problem.
///
/// Interpolating a `String` instead is left alone by `LocalizedStringKey`, so these
/// helpers both format explicitly *and* hand back a `String`.
extension Double {
    /// The value rounded to a whole number, with no grouping separator: `3000`.
    var wholeNumberText: String {
        rounded().formatted(.number.grouping(.never).precision(.fractionLength(0)))
    }
}

extension Int {
    /// The value with no grouping separator: `3000`.
    var wholeNumberText: String {
        formatted(.number.grouping(.never))
    }
}
