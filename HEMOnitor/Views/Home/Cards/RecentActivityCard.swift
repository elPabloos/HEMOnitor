//
//  RecentActivityCard.swift
//  HEMOnitor
//

import SwiftUI

/// Glass card listing injections, most recent first, scrolling internally so
/// the card's own on-screen height stays capped regardless of history length
/// (this doubles as the "view full history" affordance — every entry is here,
/// just inside a fixed-height scroller).
///
/// The title sits outside the card, matching the design mock; row content and
/// its fonts are copied from `TimelineInjectionRow` (product name, dose, date/
/// time, lot), stacked in a single glass card with a hairline separator
/// between rows rather than the Timeline's separate tinted cards.
struct RecentActivityCard: View {
    let injections: [InjectionEvent]
    let model: FactorVIIIModel
    /// Used when an event predates product tracking, so old rows show the
    /// patient's current product rather than nothing.
    let fallbackProductName: String

    private var recentFirst: [InjectionEvent] { injections.reversed() }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.stackGapSmall) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recent activity")
                    .font(.jakarta(13, weight: .bold))
                    .foregroundStyle(AppColor.inkSecondary)
                Spacer()
                Text(countText)
                    .font(.plexMono(11.5, weight: .bold))
                    .foregroundStyle(AppColor.inkSecondary)
            }
            .padding(.horizontal, 2)

            Group {
                if injections.isEmpty {
                    Text("No injections recorded yet.")
                        .font(AppTextStyle.body)
                        .foregroundStyle(AppColor.inkSecondary)
                        .padding(.vertical, 12)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(recentFirst.enumerated()), id: \.element.id) { index, injection in
                                row(for: injection)
                                if index < recentFirst.count - 1 {
                                    Rectangle()
                                        .fill(AppColor.ink.opacity(0.06))
                                        .frame(height: 1)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 260)
                }
            }
            .glassCard(cornerRadius: HomeRadius.cardLarge)
        }
    }

    private var countText: String {
        injections.isEmpty ? "none yet" : "\(injections.count) logged"
    }

    private func row(for injection: InjectionEvent) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(injection.productName ?? fallbackProductName)
                    .font(.jakarta(14.5, weight: .extraBold))
                    .foregroundStyle(AppColor.ink)

                Text("\(injection.doseIU.wholeNumberText) IU")
                    .font(.jakarta(13.5, weight: .bold))
                    .foregroundStyle(AppColor.primaryGreen)

                Text(formattedDateTime(injection.date))
                    .font(AppTextStyle.caption)
                    .foregroundStyle(AppColor.inkSecondary)

                if let lot = injection.lot {
                    Text("Lot \(lot)")
                        .font(AppTextStyle.caption)
                        .foregroundStyle(AppColor.inkSecondary)
                }
            }

            Spacer(minLength: Theme.Spacing.stackGapSmall)

            Text("\(model.displayLevel(fromRealPercent: injection.peakRealPercent).wholeNumberText)%")
                .font(AppTextStyle.monoValue)
                .foregroundStyle(AppColor.inkSecondary)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }

    /// e.g. "Monday, Sept 21, 18:23".
    private func formattedDateTime(_ date: Date) -> String {
        let weekday = date.formatted(.dateTime.weekday(.wide))
        let monthDay = date.formatted(.dateTime.month(.abbreviated).day())
        let time = date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
        return "\(weekday), \(monthDay), \(time)"
    }
}

#Preview {
    let model = FactorVIIIModel(weightKg: 65, baselinePercent: 2, halfLifeHours: 19)
    return RecentActivityCard(
        injections: [
            InjectionEvent(id: UUID(), date: Date().addingTimeInterval(-3600 * 5), doseIU: 2000, realLevelBefore: 4, peakRealPercent: 65, lot: "4363501B", productName: "Elocta"),
            InjectionEvent(id: UUID(), date: Date().addingTimeInterval(-3600 * 30), doseIU: 3000, realLevelBefore: 8, peakRealPercent: 70)
        ],
        model: model,
        fallbackProductName: "Elocta"
    )
    .padding()
    .background(AppColor.backgroundGradient)
}
