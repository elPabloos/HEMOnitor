//
//  RecentActivityCard.swift
//  HEMOnitor
//

import SwiftUI

/// Glass card listing injections, most recent first, scrolling internally so
/// the card's own on-screen height stays capped regardless of history length
/// (this doubles as the "view full history" affordance — every entry is here,
/// just inside a fixed-height scroller).
struct RecentActivityCard: View {
    let injections: [InjectionEvent]
    let model: FactorVIIIModel

    private var recentFirst: [InjectionEvent] { injections.reversed() }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.stackGap) {
            Text("Recent activity")
                .font(AppTextStyle.headline)
                .foregroundStyle(AppColor.ink)

            if injections.isEmpty {
                Text("No injections recorded yet.")
                    .font(AppTextStyle.body)
                    .foregroundStyle(AppColor.inkSecondary)
                    .padding(.vertical, 12)
            } else {
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.stackGapSmall) {
                        ForEach(recentFirst) { injection in
                            row(for: injection)
                        }
                    }
                }
                .frame(maxHeight: 260)
            }
        }
        .glassCard()
    }

    private func row(for injection: InjectionEvent) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColor.primaryGreen.opacity(0.12))
                .frame(width: 36, height: 36)
                .overlay {
                    Text(badgeCode(for: injection.doseIU))
                        .font(.plexMono(10, weight: .bold))
                        .foregroundStyle(AppColor.primaryGreen)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(injection.doseIU.wholeNumberText) IU")
                    .font(AppTextStyle.bodyEmphasis)
                    .foregroundStyle(AppColor.ink)
                Text(relativeText(for: injection.date))
                    .font(AppTextStyle.caption)
                    .foregroundStyle(AppColor.inkSecondary)
            }

            Spacer()

            Text("\(model.displayLevel(fromRealPercent: injection.peakRealPercent).wholeNumberText)%")
                .font(AppTextStyle.monoValue)
                .foregroundStyle(AppColor.inkSecondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func badgeCode(for doseIU: Double) -> String {
        if doseIU >= 1000 {
            return String(format: "%.1fK", doseIU / 1000)
        }
        return String(Int(doseIU))
    }

    private func relativeText(for date: Date) -> String {
        let hours = Date().timeIntervalSince(date) / 3600
        if hours < 1 { return "\(max(0, Int(hours * 60)))min ago" }
        if hours < 48 { return String(format: "%.1fh ago", hours) }
        return String(format: "%.1fd ago", hours / 24)
    }
}

#Preview {
    let model = FactorVIIIModel(weightKg: 65, baselinePercent: 2, halfLifeHours: 19)
    return RecentActivityCard(
        injections: [
            InjectionEvent(id: UUID(), date: Date().addingTimeInterval(-3600 * 5), doseIU: 2000, realLevelBefore: 4, peakRealPercent: 65),
            InjectionEvent(id: UUID(), date: Date().addingTimeInterval(-3600 * 30), doseIU: 3000, realLevelBefore: 8, peakRealPercent: 70)
        ],
        model: model
    )
    .padding()
    .background(AppColor.backgroundGradient)
}
