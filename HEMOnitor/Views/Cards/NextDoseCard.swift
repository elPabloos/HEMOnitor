//
//  NextDoseCard.swift
//  HEMOnitor
//

import SwiftUI

/// A purely mathematical projection: the time until the current level decays
/// down to a threshold CHOSEN BY THE USER. Not a dosing recommendation — the
/// app never suggests a threshold, it only computes the time to whichever one is entered.
struct NextDoseCard: View {
    let model: FactorVIIIModel
    let currentRealPercent: Double
    @Binding var targetText: String

    private var parsedTargetDisplayPercent: Double? {
        let normalized = targetText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard let value = Double(normalized), value.isFinite, value > 0 else { return nil }
        return value
    }

    private var hoursUntilTarget: Double? {
        guard let targetDisplay = parsedTargetDisplayPercent else { return nil }
        let targetReal = model.realPercent(fromDisplayPercent: targetDisplay)
        return model.hoursUntilLevelReaches(
            targetRealPercent: targetReal,
            fromRealPercent: currentRealPercent
        )
    }

    var body: some View {
        CardView {
            Text("Threshold projection")
                .font(.headline)

            Text("Enter a threshold (%) to see the estimated time until the level decays to it. Not a dosing recommendation.")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                TextField("Threshold (%)", text: $targetText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 120)

                Spacer()

                if let hoursUntilTarget {
                    Text(formattedDuration(hoursUntilTarget))
                        .font(.title3.bold())
                } else if targetText.isEmpty {
                    Text("—")
                        .font(.title3.bold())
                        .foregroundColor(.secondary)
                } else {
                    Text("n/a")
                        .font(.title3.bold())
                        .foregroundColor(.secondary)
                }
            }

            if !targetText.isEmpty, hoursUntilTarget == nil {
                Text("The threshold must be below the current level and above the baseline.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func formattedDuration(_ hours: Double) -> String {
        if hours < 1 {
            return String(format: "%.0f min", hours * 60)
        } else if hours < 48 {
            return String(format: "%.1f h", hours)
        } else {
            return String(format: "%.1f days", hours / 24)
        }
    }
}

#Preview {
    NextDoseCard(
        model: FactorVIIIModel(weightKg: 65, baselinePercent: 2, halfLifeHours: 19),
        currentRealPercent: 30,
        targetText: .constant("5")
    )
    .padding()
}
