//
//  ProfileEditParsing.swift
//  HEMOnitor
//

import Foundation

/// Pure formatting/parsing helpers for the profile fields shown on `ProfileRowsCard`
/// and edited in `ProfileEditSheet`. Kept free of SwiftUI so they're unit-testable
/// without touching the view layer.
enum ProfileValueFormatting {
    /// Renders a value the way it should appear both as a card value and as the
    /// starting text of an edit field: no trailing zeros, no forced decimal point.
    static func format(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        let rounded = (value * 100).rounded() / 100
        if rounded == rounded.rounded() {
            return String(Int(rounded))
        }
        var text = String(format: "%.2f", rounded)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }
}

/// Comma-tolerant parsing and validation for `ProfileEditSheet`'s fields, matching
/// the pattern used throughout the app (see `HomeView.parsedDoseIU`).
enum ProfileEditParsing {
    private static func parseDouble(_ text: String) -> Double? {
        let normalized = text
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard let value = Double(normalized), value.isFinite else { return nil }
        return value
    }

    /// Weight must be a finite, strictly positive number.
    static func parseWeight(_ text: String) -> Double? {
        guard let value = parseDouble(text), value > 0 else { return nil }
        return value
    }

    /// Baseline may be zero (a patient with no measurable baseline factor) but not negative.
    static func parseBaseline(_ text: String) -> Double? {
        guard let value = parseDouble(text), value >= 0 else { return nil }
        return value
    }

    /// Half-life must be a finite, strictly positive number (it's a decay denominator).
    static func parseHalfLife(_ text: String) -> Double? {
        guard let value = parseDouble(text), value > 0 else { return nil }
        return value
    }

    /// A product name is required; whitespace-only input doesn't count.
    static func normalizedProductName(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
