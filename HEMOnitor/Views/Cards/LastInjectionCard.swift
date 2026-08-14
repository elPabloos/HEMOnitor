//
//  LastInjectionCard.swift
//  HEMOnitor
//

import SwiftUI

/// Rezumatul ultimei injecții: doză, timp trecut, nivel înainte/după (afișat).
struct LastInjectionCard: View {
    let model: FactorVIIIModel
    let lastInjection: InjectionEvent?

    var body: some View {
        CardView {
            Text("Ultima injecție")
                .font(.headline)

            if let lastInjection {
                Text("\(Int(lastInjection.doseIU)) UI")
                    .font(.system(size: 28, weight: .bold))

                Text(elapsedText(since: lastInjection.date))
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Înainte")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(
                            format: "%.1f %%",
                            model.displayLevel(fromRealPercent: lastInjection.realLevelBefore)
                        ))
                        .font(.subheadline.bold())
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("După (peak)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(
                            format: "%.1f %%",
                            model.displayLevel(fromRealPercent: lastInjection.peakRealPercent)
                        ))
                        .font(.subheadline.bold())
                    }
                }

                Text(lastInjection.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Nicio injecție înregistrată încă.")
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func elapsedText(since date: Date) -> String {
        let hours = Date().timeIntervalSince(date) / 3600.0
        if hours < 1 {
            return String(format: "acum %.0f min", max(0, hours * 60))
        } else if hours < 48 {
            return String(format: "acum %.1f h", hours)
        } else {
            return String(format: "acum %.1f zile", hours / 24)
        }
    }
}

#Preview {
    let model = FactorVIIIModel(weightKg: 65, baselinePercent: 2, halfLifeHours: 19)
    VStack(spacing: 12) {
        LastInjectionCard(
            model: model,
            lastInjection: InjectionEvent(
                id: UUID(),
                date: Date().addingTimeInterval(-3600 * 5),
                doseIU: 2000,
                realLevelBefore: 4,
                peakRealPercent: 65
            )
        )
        LastInjectionCard(model: model, lastInjection: nil)
    }
    .padding()
}
