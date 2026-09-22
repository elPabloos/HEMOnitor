//
//  ProfileRowsCard.swift
//  HEMOnitor
//

import SwiftUI

/// The profile facts card: patient parameters and product, each a hairline-separated
/// key/value row. Read-only display — editing happens through `ProfileEditSheet`,
/// opened via the pencil button in the header.
struct ProfileRowsCard: View {
    let model: FactorVIIIModel
    let productName: String
    let onEdit: () -> Void

    private var rows: [(key: String, value: String)] {
        [
            ("Weight (kg)", ProfileValueFormatting.format(model.weightKg)),
            ("Baseline level (%)", ProfileValueFormatting.format(model.baselinePercent)),
            ("Half-life (h)", ProfileValueFormatting.format(model.halfLifeHours)),
            ("Product", productName),
            ("Recovery (%/IU/kg)", ProfileValueFormatting.format(model.recoveryPercentPerIUPerKg))
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.stackGap) {
            HStack {
                Text("Profile")
                    .font(AppTextStyle.headline)
                    .foregroundStyle(AppColor.ink)
                Spacer()
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColor.primaryGreen)
                        .frame(width: 32, height: 32)
                        .background(AppColor.glassFillStrong, in: Circle())
                }
                .accessibilityLabel("Edit profile")
            }

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    HStack {
                        Text(row.key)
                            .font(.jakarta(14.5))
                            .foregroundStyle(AppColor.inkSecondary)
                        Spacer()
                        Text(row.value)
                            .font(.plexMono(14.5, weight: .bold))
                            .foregroundStyle(AppColor.ink)
                    }
                    .padding(.vertical, 12)
                    .accessibilityElement(children: .combine)

                    if index < rows.count - 1 {
                        Rectangle()
                            .fill(AppColor.ink.opacity(0.08))
                            .frame(height: 1)
                    }
                }
            }
        }
        .glassCard()
    }
}

#Preview {
    ProfileRowsCard(
        model: FactorVIIIModel(weightKg: 65, baselinePercent: 2, halfLifeHours: 19),
        productName: "Elocta",
        onEdit: {}
    )
    .padding()
    .background(AppColor.backgroundGradient)
}
