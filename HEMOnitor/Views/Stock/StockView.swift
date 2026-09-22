//
//  StockView.swift
//  HEMOnitor
//

import SwiftUI

/// The Stock tab: total inventory at a glance (`StockHeroCard`), one row per
/// lot (`StockLotRow`), and a button to record a new delivery.
///
/// This view does not build the add-stock sheet itself (a later phase) — it
/// only exposes `onAddDelivery` for the caller to react to.
struct StockView: View {
    @ObservedObject var viewModel: StockViewModel
    let onAddDelivery: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.stackGapLarge) {
                StockHeroCard(
                    totalIU: viewModel.totalIU,
                    totalVialCount: viewModel.totalVialCount,
                    daysOfCoverage: viewModel.daysOfCoverage,
                    soonestExpiry: viewModel.soonestExpiry
                )

                if viewModel.batches.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: Theme.Spacing.stackGap) {
                        ForEach(viewModel.batches) { batch in
                            StockLotRow(batch: batch)
                        }
                    }
                }

                addDeliveryButton
            }
            .padding(.horizontal, Theme.Spacing.screenGutter)
            .padding(.top, Theme.Spacing.screenGutter)
        }
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.stackGapSmall) {
            Image(systemName: "shippingbox")
                .font(.system(size: 34))
                .foregroundStyle(AppColor.inkTertiary)
            Text("No stock recorded yet")
                .font(AppTextStyle.headline)
                .foregroundStyle(AppColor.ink)
            Text("Add your first delivery to start tracking vials on hand.")
                .font(AppTextStyle.body)
                .foregroundStyle(AppColor.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.stackGapLarge)
        .glassCard(cornerRadius: Theme.Radius.card)
        .accessibilityElement(children: .combine)
    }

    private var addDeliveryButton: some View {
        Button(action: onAddDelivery) {
            Text("+ Add a delivery")
                .font(.jakarta(16, weight: .bold))
                .foregroundStyle(AppColor.primaryGreen)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background {
                    Capsule()
                        .strokeBorder(AppColor.primaryGreen.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                }
        }
        .accessibilityLabel("Add a delivery")
    }
}

#Preview("With stock") {
    StockView(
        viewModel: StockViewModel(batches: [
            StockBatch(
                productName: "Elocta",
                lotNumber: "L123",
                expiryDate: Date().addingTimeInterval(86400 * 400),
                vialSizeIU: 1500,
                quantity: 4
            ),
            StockBatch(
                productName: "Elocta",
                lotNumber: "A987",
                expiryDate: Date().addingTimeInterval(86400 * 10),
                vialSizeIU: 750,
                quantity: 2
            ),
            StockBatch(
                productName: "Elocta",
                lotNumber: "X001",
                expiryDate: Date().addingTimeInterval(-86400 * 2),
                vialSizeIU: 3000,
                quantity: 1
            )
        ]),
        onAddDelivery: {}
    )
    .background(AppColor.backgroundGradient)
}

#Preview("Empty") {
    StockView(viewModel: StockViewModel(batches: []), onAddDelivery: {})
        .background(AppColor.backgroundGradient)
}
