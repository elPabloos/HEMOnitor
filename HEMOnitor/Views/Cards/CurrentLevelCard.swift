//
//  CurrentLevelCard.swift
//  HEMOnitor
//

import SwiftUI

/// The main card: the current estimated (or simulated) level, colored by
/// safety zone, with a clear indicator when the displayed data is from a
/// time simulation rather than the real current state.
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
                Text(isSimulated ? "Simulated level" : "Estimated current level")
                    .font(.headline)
                Spacer()
                if isSimulated {
                    Label("Simulation mode", systemImage: "clock.arrow.circlepath")
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
                Text("Simulated time: \(simulatedDate.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Estimated from doses and half-life decay. Not a substitute for lab tests.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            (isSimulated ? "Simulated level" : "Estimated current level") +
            String(format: ", %.1f percent, %@ zone", shownPercent, zone.label)
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
