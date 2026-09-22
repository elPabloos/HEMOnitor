//
//  LogDoseSheet.swift
//  HEMOnitor
//

import SwiftUI

/// Records an injection, either by drawing vials from stock or by typing a dose.
///
/// The mock has these as two separate sheets. They are one sheet with a source
/// toggle here because everything except how the dose is *sourced* is identical —
/// the date/time picker, the predicted-effect summary, and the save path are shared.
/// Splitting them would duplicate all of that for one differing section.
struct LogDoseSheet: View {
    @ObservedObject var viewModel: FactorTrackerViewModel
    @ObservedObject var stockViewModel: StockViewModel
    var onClose: () -> Void

    enum Source: String, CaseIterable, Identifiable {
        case stock, manual
        var id: String { rawValue }
        var title: String { self == .stock ? "From stock" : "Manual" }
    }

    @State private var source: Source = .stock
    @State private var date = Date()
    @State private var vialCounts: [UUID: Int] = [:]
    @State private var manualDoseText = ""
    @State private var errorMessage: String?

    /// Captured once so the picker's upper bound doesn't drift while the sheet is open.
    private let openedAt = Date()

    var body: some View {
        SheetChrome(title: "Log a dose", onClose: onClose) {
            ScrollView {
                VStack(spacing: Theme.Spacing.stackGapLarge) {
                    sourcePicker
                    if source == .stock { stockSection } else { manualSection }
                    dateSection
                    summarySection
                    if let errorMessage {
                        Text(errorMessage)
                            .font(AppTextStyle.caption)
                            .foregroundStyle(AppColor.dangerForeground)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Button("Log dose", action: save)
                        .buttonStyle(.primaryPill)
                        .disabled(doseIU <= 0)
                        .opacity(doseIU <= 0 ? 0.5 : 1)
                }
                .padding(.horizontal, Theme.Spacing.screenGutter)
                .padding(.vertical, Theme.Spacing.stackGapLarge)
            }
        }
    }

    // MARK: - Sections

    private var sourcePicker: some View {
        Picker("Dose source", selection: $source) {
            ForEach(Source.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var stockSection: some View {
        if stockViewModel.batches.isEmpty {
            VStack(spacing: Theme.Spacing.stackGapSmall) {
                Text("No stock on record")
                    .font(AppTextStyle.bodyEmphasis)
                    .foregroundStyle(AppColor.warningForeground)
                Text("Add a delivery first, or switch to Manual to log a dose anyway.")
                    .font(AppTextStyle.caption)
                    .foregroundStyle(AppColor.inkSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .glassCard()
        } else {
            VStack(spacing: Theme.Spacing.stackGap) {
                ForEach(stockViewModel.batches) { batch in
                    vialStepper(for: batch)
                }
            }
        }
    }

    private func vialStepper(for batch: StockBatch) -> some View {
        let count = vialCounts[batch.id] ?? 0
        return HStack(spacing: Theme.Spacing.stackGap) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Int(batch.vialSizeIU)) IU")
                    .font(.jakarta(15, weight: .bold))
                    .foregroundStyle(AppColor.ink)
                Text("lot \(batch.lotNumber) · \(batch.quantity) available")
                    .font(AppTextStyle.caption)
                    .foregroundStyle(AppColor.inkSecondary)
            }
            Spacer()
            stepperButton(systemName: "minus", enabled: count > 0) {
                vialCounts[batch.id] = max(0, count - 1)
            }
            Text("\(count)")
                .font(.plexMono(17, weight: .bold))
                .foregroundStyle(AppColor.ink)
                .frame(minWidth: 28)
            stepperButton(systemName: "plus", enabled: count < batch.quantity) {
                vialCounts[batch.id] = min(batch.quantity, count + 1)
            }
        }
        .glassCard(cornerRadius: Theme.Radius.card, padding: Theme.Spacing.cardPaddingCompact)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(Int(batch.vialSizeIU)) IU vials, lot \(batch.lotNumber), \(count) selected of \(batch.quantity)")
    }

    private func stepperButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(enabled ? AppColor.primaryGreen : AppColor.inkTertiary)
                // 44pt keeps the tap target at the accessibility minimum.
                .frame(width: 44, height: 44)
                .background(AppColor.glassFillStrong, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private var manualSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.stackGapSmall) {
            Text("Dose")
                .font(AppTextStyle.kicker)
                .foregroundStyle(AppColor.inkSecondary)
            TextField("Dose (IU)", text: $manualDoseText)
                .keyboardType(.decimalPad)
                .font(.plexMono(17, weight: .bold))
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(AppColor.glassFillStrong, in: RoundedRectangle(cornerRadius: Theme.Radius.input, style: .continuous))
            if !manualDoseText.isEmpty && parsedManualDose == nil {
                Text("Enter a valid dose greater than 0.")
                    .font(AppTextStyle.caption)
                    .foregroundStyle(AppColor.inkSecondary)
            }
        }
        .glassCard()
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.stackGapSmall) {
            Text("When")
                .font(AppTextStyle.kicker)
                .foregroundStyle(AppColor.inkSecondary)
            // Native wheel picker rather than a hand-rolled three-column one: it is
            // the same interaction, already localized and accessible. Capped at the
            // present, since a dose can be back-dated but not pre-recorded.
            DatePicker(
                "Dose date and time",
                selection: $date,
                in: ...openedAt,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
        }
        .glassCard()
    }

    private var summarySection: some View {
        VStack(spacing: Theme.Spacing.stackGapSmall) {
            SheetSummaryRow(label: "Total dose", value: "\(Int(doseIU)) IU", emphasized: true)
            if let plan {
                SheetSummaryRow(
                    label: "Predicted level",
                    value: String(format: "%.0f %%", plan.predictedPeakDisplayPercent)
                )
                SheetSummaryRow(
                    label: "Above 5% for",
                    value: plan.hoursUntilThreshold.map(DoseLogPlan.formattedDuration) ?? "—"
                )
                if let stockAfter = plan.stockAfterIU {
                    SheetSummaryRow(label: "Stock after", value: "\(Int(stockAfter)) IU")
                }
            }
        }
        .glassCard()
    }

    // MARK: - Derived values

    private var parsedManualDose: Double? {
        let normalized = manualDoseText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard let dose = Double(normalized), dose.isFinite, dose > 0 else { return nil }
        return dose
    }

    private var doseIU: Double {
        switch source {
        case .stock: return DoseLogPlan.totalIU(selection: vialCounts, batches: stockViewModel.batches)
        case .manual: return parsedManualDose ?? 0
        }
    }

    private var plan: DoseLogPlan? {
        guard doseIU > 0 else { return nil }
        return DoseLogPlan.make(
            doseIU: doseIU,
            model: viewModel.model,
            // The dose stacks on whatever is left at the moment it's given, which for a
            // back-dated entry is not the level right now.
            currentRealPercent: realLevelAt(date),
            stockTotalIU: source == .stock ? stockViewModel.totalIU : nil
        )
    }

    /// Real level at an arbitrary instant, without disturbing the view model's
    /// published "current" values (which track now, not the sheet's chosen date).
    private func realLevelAt(_ moment: Date) -> Double {
        guard let previous = viewModel.injections.last(where: { $0.date <= moment }) else {
            return viewModel.model.baselinePercent
        }
        return viewModel.model.levelAtTime(
            peakPercent: previous.peakRealPercent,
            hoursSincePeak: max(0, moment.timeIntervalSince(previous.peakDate) / 3600)
        )
    }

    // MARK: - Save

    private func save() {
        guard doseIU > 0 else { return }

        if source == .stock {
            // Take the vials out first: if stock can't cover it, nothing is recorded.
            // consume() rejects rather than clamping, so a failure here means the
            // selection went stale and the injection must not be written.
            for (batchId, count) in vialCounts where count > 0 {
                guard stockViewModel.consume(vials: count, fromBatchId: batchId) else {
                    errorMessage = "Not enough vials left in that lot. Refresh your selection and try again."
                    return
                }
            }
        }

        viewModel.addInjection(doseIU: doseIU, at: date)
        onClose()
    }
}

#Preview {
    LogDoseSheet(
        viewModel: FactorTrackerViewModel(settings: .defaultSettings),
        stockViewModel: StockViewModel(batches: [
            StockBatch(productName: "Elocta", lotNumber: "A24K18", expiryDate: Date().addingTimeInterval(86_400 * 200), vialSizeIU: 1500, quantity: 4)
        ]),
        onClose: {}
    )
}
