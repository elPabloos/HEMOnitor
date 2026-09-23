//
//  StockLotRow.swift
//  HEMOnitor
//

import SwiftUI

/// One card summarizing a single `StockBatch` (a "lot"): vial size and product,
/// how many vials remain, and an expiry badge alongside the lot's total IU.
struct StockLotRow: View {
    let batch: StockBatch

    private var totalIU: Double { batch.vialSizeIU * Double(batch.quantity) }
    private var vialsSuffix: String { batch.quantity == 1 ? "vial" : "vials" }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.stackGap) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(batch.vialSizeIU.wholeNumberText) IU")
                        .font(.jakarta(17, weight: .extraBold))
                        .foregroundStyle(AppColor.ink)

                    (Text("\(batch.productName) · lot ")
                        + Text(batch.lotNumber).font(.plexMono(12, weight: .medium)))
                        .font(AppTextStyle.caption)
                        .foregroundStyle(AppColor.inkSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(batch.quantity)")
                        .font(.jakarta(22, weight: .extraBold))
                        .foregroundStyle(AppColor.ink)
                    Text(vialsSuffix)
                        .font(AppTextStyle.caption)
                        .foregroundStyle(AppColor.inkSecondary)
                }
            }

            HStack {
                ExpiryBadge(expiryDate: batch.expiryDate)
                Spacer()
                Text("\(totalIU.wholeNumberText) IU total")
                    .font(AppTextStyle.monoLabel)
                    .foregroundStyle(AppColor.inkSecondary)
            }
        }
        .glassCard(cornerRadius: Theme.Radius.card)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Theme.Spacing.stackGap) {
            StockLotRow(batch: StockBatch(
                productName: "Elocta",
                lotNumber: "L123",
                expiryDate: Date().addingTimeInterval(86400 * 400),
                vialSizeIU: 1500,
                quantity: 4
            ))
            StockLotRow(batch: StockBatch(
                productName: "Elocta",
                lotNumber: "A987",
                expiryDate: Date().addingTimeInterval(86400 * 10),
                vialSizeIU: 750,
                quantity: 2
            ))
            StockLotRow(batch: StockBatch(
                productName: "Elocta",
                lotNumber: "X001",
                expiryDate: Date().addingTimeInterval(-86400 * 2),
                vialSizeIU: 3000,
                quantity: 1
            ))
        }
        .padding()
    }
    .background(AppColor.backgroundGradient)
}
