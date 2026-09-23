//
//  EditInjectionSheet.swift
//  HEMOnitor
//

import SwiftUI

/// Corrects or removes a logged injection.
///
/// Writes through `FactorTrackerViewModel.updateInjection`/`deleteInjection`, which
/// already splice the chain and recompute every event after the change — so re-dating
/// a dose to before its neighbours is supported here and needs no guard.
///
/// Dose parsing mirrors `LogDoseSheet.parsedManualDose`: commas normalised, anything
/// non-finite or ≤ 0 rejected, with the save button gated on it.
struct EditInjectionSheet: View {
    @ObservedObject var viewModel: FactorTrackerViewModel
    let injection: InjectionEvent
    let onClose: () -> Void

    @State private var doseText: String
    @State private var date: Date
    @State private var showingDeleteConfirmation = false

    /// Captured once so the picker's upper bound doesn't drift while the sheet is open.
    private let openedAt = Date()

    init(viewModel: FactorTrackerViewModel, injection: InjectionEvent, onClose: @escaping () -> Void) {
        self.viewModel = viewModel
        self.injection = injection
        self.onClose = onClose
        _doseText = State(initialValue: Self.format(doseIU: injection.doseIU))
        _date = State(initialValue: injection.date)
    }

    var body: some View {
        SheetChrome(title: "Edit injection", onClose: onClose) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.stackGapLarge) {
                    doseSection
                    dateSection
                    provenanceSection
                    saveButton
                    deleteButton
                }
                .padding(.horizontal, Theme.Spacing.screenGutter)
                .padding(.vertical, Theme.Spacing.stackGapLarge)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .alert("Delete this injection?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                viewModel.deleteInjection(id: injection.id)
                onClose()
            }
        } message: {
            Text("Levels recorded after it will be recalculated without this dose.")
        }
    }

    // MARK: - Sections

    private var doseSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.stackGapSmall) {
            Text("Dose")
                .font(AppTextStyle.kicker)
                .foregroundStyle(AppColor.inkSecondary)

            HStack {
                TextField("Dose", text: $doseText)
                    .keyboardType(.decimalPad)
                    .font(.jakarta(22, weight: .extraBold))
                    .foregroundStyle(AppColor.ink)

                Text("IU")
                    .font(AppTextStyle.body)
                    .foregroundStyle(AppColor.inkSecondary)
            }

            if parsedDose == nil {
                Text("Enter a dose greater than 0.")
                    .font(AppTextStyle.caption)
                    .foregroundStyle(AppColor.dangerForeground)
            }
        }
        .glassCard()
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.stackGapSmall) {
            Text("When")
                .font(AppTextStyle.kicker)
                .foregroundStyle(AppColor.inkSecondary)

            DatePicker(
                "Injection date and time",
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

    /// Lot and product are recorded when the dose is logged and are not editable here
    /// — correcting *which vial* was used is a different operation from correcting the
    /// dose or the time, and would have to reconcile stock to be meaningful.
    @ViewBuilder
    private var provenanceSection: some View {
        if injection.lot != nil || injection.productName != nil {
            VStack(spacing: Theme.Spacing.stackGapSmall) {
                if let product = injection.productName {
                    SheetSummaryRow(label: "Product", value: product)
                }
                if let lot = injection.lot {
                    SheetSummaryRow(label: "Lot", value: lot)
                }
            }
            .glassCard()
        }
    }

    private var saveButton: some View {
        Button("Save changes") {
            guard let dose = parsedDose else { return }
            viewModel.updateInjection(id: injection.id, doseIU: dose, date: date)
            onClose()
        }
        .buttonStyle(.primaryPill)
        .disabled(parsedDose == nil)
        .opacity(parsedDose == nil ? 0.5 : 1)
    }

    /// Styled inline rather than with `.secondaryPill`, which hard-codes its own
    /// foreground colour and would render this grey. Matches the destructive reset
    /// button in `YouView`.
    private var deleteButton: some View {
        Button {
            showingDeleteConfirmation = true
        } label: {
            Text("Delete injection")
                .font(.jakarta(15, weight: .bold))
                .foregroundStyle(AppColor.dangerForeground)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background {
                    Capsule()
                        .fill(AppColor.dangerBackground)
                        .overlay(Capsule().strokeBorder(AppColor.dangerForeground, lineWidth: 1))
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Derived values

    private var parsedDose: Double? {
        let normalized = doseText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard let dose = Double(normalized), dose.isFinite, dose > 0 else { return nil }
        return dose
    }

    /// Whole doses lose their ".0" so the field reads the way the user typed it.
    private static func format(doseIU: Double) -> String {
        doseIU == doseIU.rounded() ? String(Int(doseIU)) : String(doseIU)
    }
}
