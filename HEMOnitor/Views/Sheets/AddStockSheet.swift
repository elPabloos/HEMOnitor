//
//  AddStockSheet.swift
//  HEMOnitor
//

import SwiftUI

/// Records a delivery of vials into stock.
struct AddStockSheet: View {
    @ObservedObject var stockViewModel: StockViewModel
    var defaultProductName: String
    var onClose: () -> Void

    private static let vialSizes: [Double] = [250, 500, 1000, 1500, 2000, 3000]

    @State private var vialSizeIU: Double = 1000
    @State private var quantity: Int = 1
    @State private var lotNumber = ""
    @State private var expiryDate = Calendar.current.date(byAdding: .month, value: 12, to: Date()) ?? Date()

    private let openedAt = Date()

    var body: some View {
        SheetChrome(title: "Add a delivery", onClose: onClose) {
            ScrollView {
                VStack(spacing: Theme.Spacing.stackGapLarge) {
                    vialSizeSection
                    quantitySection
                    lotSection
                    expirySection
                    SheetSummaryRow(
                        label: "Total added",
                        value: "\(Int(vialSizeIU * Double(quantity))) IU",
                        emphasized: true
                    )
                    .glassCard()

                    Button("Add to stock", action: save)
                        .buttonStyle(.primaryPill)
                        .disabled(!isValid)
                        .opacity(isValid ? 1 : 0.5)
                }
                .padding(.horizontal, Theme.Spacing.screenGutter)
                .padding(.vertical, Theme.Spacing.stackGapLarge)
            }
        }
    }

    private var vialSizeSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.stackGapSmall) {
            Text("Vial size")
                .font(AppTextStyle.kicker)
                .foregroundStyle(AppColor.inkSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Self.vialSizes, id: \.self) { size in
                        let selected = size == vialSizeIU
                        Button {
                            vialSizeIU = size
                        } label: {
                            Text(size.wholeNumberText)
                                .font(.plexMono(14, weight: .bold))
                                .foregroundStyle(selected ? .white : AppColor.ink)
                                .padding(.horizontal, 16)
                                .frame(height: 44)
                                .background(
                                    selected ? AnyShapeStyle(AppColor.primaryGreen) : AnyShapeStyle(AppColor.glassFillStrong),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(Int(size)) IU vial")
                        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
                    }
                }
            }
        }
        .glassCard()
    }

    private var quantitySection: some View {
        HStack {
            Text("Number of vials")
                .font(AppTextStyle.caption)
                .foregroundStyle(AppColor.inkSecondary)
            Spacer()
            Stepper(value: $quantity, in: 1...99) {
                Text("\(quantity)")
                    .font(.plexMono(17, weight: .bold))
                    .foregroundStyle(AppColor.ink)
            }
            .fixedSize()
        }
        .glassCard()
    }

    private var lotSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.stackGapSmall) {
            Text("Lot number")
                .font(AppTextStyle.kicker)
                .foregroundStyle(AppColor.inkSecondary)
            TextField("e.g. A24K18", text: $lotNumber)
                .font(.plexMono(15, weight: .medium))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(AppColor.glassFillStrong, in: RoundedRectangle(cornerRadius: Theme.Radius.input, style: .continuous))
        }
        .glassCard()
    }

    private var expirySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.stackGapSmall) {
            Text("Expires")
                .font(AppTextStyle.kicker)
                .foregroundStyle(AppColor.inkSecondary)
            // Future-only: stock that has already expired isn't a delivery.
            DatePicker("Expiry date", selection: $expiryDate, in: openedAt..., displayedComponents: .date)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .glassCard()
    }

    private var isValid: Bool {
        !lotNumber.trimmingCharacters(in: .whitespaces).isEmpty && quantity >= 1 && vialSizeIU > 0
    }

    private func save() {
        guard isValid else { return }
        stockViewModel.addBatch(
            StockBatch(
                productName: defaultProductName,
                lotNumber: lotNumber.trimmingCharacters(in: .whitespaces),
                expiryDate: expiryDate,
                vialSizeIU: vialSizeIU,
                quantity: quantity
            )
        )
        onClose()
    }
}

#Preview {
    AddStockSheet(
        stockViewModel: StockViewModel(),
        defaultProductName: "Elocta",
        onClose: {}
    )
}
