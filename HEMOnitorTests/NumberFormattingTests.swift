//
//  NumberFormattingTests.swift
//  HEMOnitorTests
//

import Testing
import Foundation
@testable import HEMOnitor

/// Guards the dose/IU rendering helpers.
///
/// The bug these exist for: `Text("\(Int(dose)) IU")` is a `LocalizedStringKey`, so
/// SwiftUI formats the integer through the locale and a 3000 IU dose renders as
/// "3.000 IU" in a dot-grouping locale. These assert the helpers never group,
/// whatever the locale.
struct NumberFormattingTests {

    @Test func thousandsAreNotGrouped() {
        #expect(3000.0.wholeNumberText == "3000")
        #expect(4850.0.wholeNumberText == "4850")
        #expect(10_000.0.wholeNumberText == "10000")
    }

    @Test func smallValuesAreUnchanged() {
        #expect(0.0.wholeNumberText == "0")
        #expect(79.0.wholeNumberText == "79")
        #expect(999.0.wholeNumberText == "999")
    }

    @Test func fractionsAreRoundedToWholeNumbers() {
        #expect(78.4.wholeNumberText == "78")
        #expect(78.6.wholeNumberText == "79")
        #expect(2999.5.wholeNumberText == "3000")
    }

    @Test func negativeValuesKeepTheirSign() {
        // Not expected in practice, but the helper shouldn't mangle them.
        #expect((-5.0).wholeNumberText == "-5")
    }

    @Test func intHelperMatchesTheDoubleHelper() {
        #expect(3000.wholeNumberText == 3000.0.wholeNumberText)
        #expect(19.wholeNumberText == "19")
    }

    @Test func outputNeverContainsAGroupingSeparator() {
        // The actual invariant, independent of which separator a locale would use.
        for value in [1000.0, 12_345.0, 999_999.0] {
            let text = value.wholeNumberText
            #expect(!text.contains(","))
            #expect(!text.contains("."))
            #expect(!text.contains("\u{00A0}"))  // non-breaking space grouping
            #expect(!text.contains("\u{202F}"))  // narrow no-break space grouping
        }
    }
}
