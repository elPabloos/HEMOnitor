//
//  TimelineInjectionRow.swift
//  HEMOnitor
//

import SwiftUI

/// One logged injection in the timeline list: product, dose, when, and which lot it
/// came from.
///
/// The whole row is a button — tapping it opens the editor — with a trailing chevron
/// so that affordance is visible rather than hidden behind a swipe. This is why the
/// screen needs no `List`: the rest of the app scrolls `VStack`s of cards, and a tap
/// target works with VoiceOver without any extra wiring.
struct TimelineInjectionRow: View {
    let injection: InjectionEvent
    /// Used when the event predates product tracking, so old rows show the patient's
    /// current product rather than nothing.
    let fallbackProductName: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.Spacing.stackGap) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(injection.productName ?? fallbackProductName)
                        .font(.jakarta(14.5, weight: .extraBold))
                        .foregroundStyle(AppColor.ink)

                    Text("\(formattedDose) IU")
                        .font(.jakarta(13.5, weight: .bold))
                        .foregroundStyle(AppColor.primaryGreen)

                    Text(injection.date.formatted(.dateTime.month(.wide).day()) + " · " + injection.date.formatted(date: .omitted, time: .shortened))
                        .font(AppTextStyle.caption)
                        .foregroundStyle(AppColor.inkSecondary)

                    if let lot = injection.lot {
                        Text("Lot \(lot)")
                            .font(AppTextStyle.caption)
                            .foregroundStyle(AppColor.inkSecondary)
                    }
                }

                Spacer(minLength: Theme.Spacing.stackGapSmall)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColor.ink.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppColor.primaryGreen.opacity(0.14),
                                AppColor.accentGreen.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(AppColor.primaryGreen.opacity(0.16), lineWidth: 1)
            }
            // Without this the gradient background isn't part of the hit region and
            // only the text would be tappable.
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the editor for this injection")
        .accessibilityAddTraits(.isButton)
    }

    /// Rendered without a grouping separator, matching `RecentActivityCard` on Home.
    /// Locale grouping is actively harmful here: in a locale that groups with "."
    /// a 3000 IU dose reads as "3.000 IU", i.e. three.
    private var formattedDose: String {
        injection.doseIU.formatted(.number.grouping(.never).precision(.fractionLength(0...1)))
    }
}

#Preview {
    ZStack {
        AppColor.backgroundGradient.ignoresSafeArea()
        VStack(spacing: 9) {
            TimelineInjectionRow(
                injection: InjectionEvent(
                    id: UUID(),
                    date: Date(),
                    doseIU: 3000,
                    realLevelBefore: 2,
                    peakRealPercent: 94,
                    lot: "4363501B",
                    productName: "Elocta"
                ),
                fallbackProductName: "Elocta",
                onTap: {}
            )

            TimelineInjectionRow(
                injection: InjectionEvent(
                    id: UUID(),
                    date: Date().addingTimeInterval(-86_400),
                    doseIU: 1500,
                    realLevelBefore: 4,
                    peakRealPercent: 50
                ),
                fallbackProductName: "Elocta",
                onTap: {}
            )
        }
        .padding(14)
    }
}
