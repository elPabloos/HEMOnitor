//
//  NextDoseCard.swift
//  HEMOnitor
//

import SwiftUI

/// Proiecție pur matematică: timpul până când nivelul curent va ajunge (prin
/// decădere) la un prag ALES DE UTILIZATOR. Nu este o recomandare de dozaj —
/// aplicația nu sugerează niciun prag, doar calculează timpul pentru cel introdus.
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
            Text("Proiecție prag")
                .font(.headline)

            Text("Introdu un prag (%) și vezi timpul estimat până când nivelul ajunge la acea valoare, pe baza decăderii curente. Nu este o recomandare de dozaj.")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                TextField("Prag (%)", text: $targetText)
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
                Text("Pragul trebuie să fie sub nivelul curent și peste valoarea de bază.")
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
            return String(format: "%.1f zile", hours / 24)
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
