//
//  StockHeroCard.swift
//  HEMOnitor
//

import SwiftUI

/// The Stock tab's hero card: total IU on hand, plus at-a-glance coverage and
/// soonest-expiry figures. Purely presentational — every value is handed in.
struct StockHeroCard: View {
    let totalIU: Double
    let totalVialCount: Int
    let daysOfCoverage: Int?
    let soonestExpiry: Date?

    private var vialsSuffix: String {
        totalVialCount == 1 ? "vial" : "vials"
    }

    private var coverageText: String {
        guard let daysOfCoverage else { return "—" }
        return daysOfCoverage == 1 ? "1 day" : "\(daysOfCoverage) days"
    }

    private var soonestExpiryText: String {
        guard let soonestExpiry else { return "—" }
        return soonestExpiry.formatted(.dateTime.day().month(.abbreviated).year())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.stackGap) {
            Text("TOTAL ON HAND")
                .font(AppTextStyle.kicker)
                .tracking(1.1)
                .foregroundStyle(.white.opacity(0.78))

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(totalIU.wholeNumberText)
                    .font(.plexMono(44, weight: .extraBold))
                    .foregroundStyle(.white)
                Text("IU · \(totalVialCount) \(vialsSuffix)")
                    .font(AppTextStyle.body.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }

            Divider()
                .overlay(.white.opacity(0.28))
                .padding(.vertical, 2)

            HStack {
                heroStat(label: "Covers", value: coverageText)
                Spacer()
                heroStat(label: "Soonest expiry", value: soonestExpiryText, alignment: .trailing)
            }
        }
        .padding(Theme.Spacing.cardPadding)
        .background(AppColor.brandGradient, in: RoundedRectangle(cornerRadius: Theme.Radius.cardLarge, style: .continuous))
        .themeShadow(.ctaGreen)
        .accessibilityElement(children: .combine)
    }

    private func heroStat(label: String, value: String, alignment: HorizontalAlignment = .leading) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(label)
                .font(AppTextStyle.caption)
                .foregroundStyle(.white.opacity(0.72))
            Text(value)
                .font(AppTextStyle.bodyEmphasis)
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        StockHeroCard(totalIU: 12500, totalVialCount: 6, daysOfCoverage: 18, soonestExpiry: Date().addingTimeInterval(86400 * 12))
        StockHeroCard(totalIU: 0, totalVialCount: 0, daysOfCoverage: nil, soonestExpiry: nil)
    }
    .padding()
    .background(AppColor.backgroundGradient)
}
