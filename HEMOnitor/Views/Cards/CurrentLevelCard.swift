//
//  CurrentLevelCard.swift
//  HEMOnitor
//

import SwiftUI

/// Cardul principal: nivelul curent estimat (sau simulat), colorat după zona
/// de siguranță, cu indicator clar când datele afișate sunt dintr-o simulare
/// de timp și nu din starea reală curentă.
struct CurrentLevelCard: View {
    let realDisplayPercent: Double
    let isSimulated: Bool
    let simulatedDisplayPercent: Double
    let simulatedDate: Date
    let simulatedDaysText: String?

    private var shownPercent: Double {
        isSimulated ? simulatedDisplayPercent : realDisplayPercent
    }

    private var zone: SafetyZone { SafetyZone(displayPercent: shownPercent) }

    var body: some View {
        CardView(tint: zone.color) {
            HStack {
                Text(isSimulated ? "Nivel simulat" : "Nivel curent estimat")
                    .font(.headline)
                Spacer()
                if isSimulated {
                    Label("Mod simulare", systemImage: "clock.arrow.circlepath")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }
                if let simulatedDaysText, isSimulated {
                    Text(simulatedDaysText)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(String(format: "%.1f %%", shownPercent))
                    .font(.system(size: 40, weight: .bold))
                Text(zone.label)
                    .font(.subheadline.bold())
                    .foregroundColor(zone.color)
            }

            if isSimulated {
                Text("Ora simulată: \(simulatedDate.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Valoare estimată pe baza dozelor și a timpului de înjumătățire. Nu înlocuiește analizele de laborator.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            (isSimulated ? "Nivel simulat" : "Nivel curent estimat") +
            String(format: ", %.1f procente, zonă %@", shownPercent, zone.label)
        )
    }
}

#Preview {
    VStack(spacing: 12) {
        CurrentLevelCard(
            realDisplayPercent: 62,
            isSimulated: false,
            simulatedDisplayPercent: 62,
            simulatedDate: Date(),
            simulatedDaysText: nil
        )
        CurrentLevelCard(
            realDisplayPercent: 62,
            isSimulated: true,
            simulatedDisplayPercent: 3.2,
            simulatedDate: Date(),
            simulatedDaysText: "2d"
        )
    }
    .padding()
}
