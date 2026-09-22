//
//  ProfileEditParsingTests.swift
//  HEMOnitorTests
//

import Testing
@testable import HEMOnitor

/// Pure-function tests for the "You" tab's profile edit sheet — parsing/validation
/// and the display formatting, independent of the SwiftUI layer.
struct ProfileEditParsingTests {

    // MARK: - Formatting

    @Test func formatDropsTrailingZerosForWholeNumbers() {
        #expect(ProfileValueFormatting.format(65) == "65")
        #expect(ProfileValueFormatting.format(19.0) == "19")
    }

    @Test func formatKeepsMeaningfulDecimals() {
        #expect(ProfileValueFormatting.format(2.5) == "2.5")
        #expect(ProfileValueFormatting.format(2.0) != "2.0") // trimmed to "2"
    }

    @Test func formatRoundsToTwoDecimalPlaces() {
        #expect(ProfileValueFormatting.format(2.567) == "2.57")
    }

    @Test func formatHandlesNonFiniteValues() {
        #expect(ProfileValueFormatting.format(.nan) == "—")
        #expect(ProfileValueFormatting.format(.infinity) == "—")
    }

    // MARK: - Weight

    @Test func parseWeightAcceptsPositiveValues() {
        #expect(ProfileEditParsing.parseWeight("65") == 65)
        #expect(ProfileEditParsing.parseWeight("65,5") == 65.5) // comma-tolerant
    }

    @Test func parseWeightRejectsZeroNegativeOrGarbage() {
        #expect(ProfileEditParsing.parseWeight("0") == nil)
        #expect(ProfileEditParsing.parseWeight("-5") == nil)
        #expect(ProfileEditParsing.parseWeight("abc") == nil)
        #expect(ProfileEditParsing.parseWeight("") == nil)
    }

    // MARK: - Baseline

    @Test func parseBaselineAcceptsZero() {
        #expect(ProfileEditParsing.parseBaseline("0") == 0)
    }

    @Test func parseBaselineRejectsNegative() {
        #expect(ProfileEditParsing.parseBaseline("-1") == nil)
    }

    // MARK: - Half-life

    @Test func parseHalfLifeRejectsZeroOrNegative() {
        #expect(ProfileEditParsing.parseHalfLife("0") == nil)
        #expect(ProfileEditParsing.parseHalfLife("-19") == nil)
        #expect(ProfileEditParsing.parseHalfLife("19") == 19)
    }

    // MARK: - Product name

    @Test func normalizedProductNameTrimsWhitespace() {
        #expect(ProfileEditParsing.normalizedProductName("  Elocta  ") == "Elocta")
    }

    @Test func normalizedProductNameRejectsBlank() {
        #expect(ProfileEditParsing.normalizedProductName("") == nil)
        #expect(ProfileEditParsing.normalizedProductName("   ") == nil)
    }
}
