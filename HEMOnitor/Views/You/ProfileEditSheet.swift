//
//  ProfileEditSheet.swift
//  HEMOnitor
//

import SwiftUI

/// Sheet for editing the patient parameters and product name shown on `ProfileRowsCard`.
/// Comma-tolerant parsing and inline validation match the rest of the app (see
/// `HomeView.parsedDoseIU`/`doseValidationMessage`). Only fields the user actually
/// changed are sent to `FactorTrackerViewModel.updatePatientParameters`, since all of
/// its parameters are optional and "unchanged" is its way of saying "leave alone".
struct ProfileEditSheet: View {
    @ObservedObject var viewModel: FactorTrackerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var weightText: String
    @State private var baselineText: String
    @State private var halfLifeText: String
    @State private var productNameText: String

    private let initialWeight: Double
    private let initialBaseline: Double
    private let initialHalfLife: Double
    private let initialProductName: String

    init(viewModel: FactorTrackerViewModel) {
        self.viewModel = viewModel
        let model = viewModel.model
        _weightText = State(initialValue: ProfileValueFormatting.format(model.weightKg))
        _baselineText = State(initialValue: ProfileValueFormatting.format(model.baselinePercent))
        _halfLifeText = State(initialValue: ProfileValueFormatting.format(model.halfLifeHours))
        _productNameText = State(initialValue: viewModel.productName)
        initialWeight = model.weightKg
        initialBaseline = model.baselinePercent
        initialHalfLife = model.halfLifeHours
        initialProductName = viewModel.productName
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Weight (kg)", text: $weightText)
                            .keyboardType(.decimalPad)
                        if let weightValidationMessage {
                            Text(weightValidationMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Baseline level (%)", text: $baselineText)
                            .keyboardType(.decimalPad)
                        if let baselineValidationMessage {
                            Text(baselineValidationMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Half-life (h)", text: $halfLifeText)
                            .keyboardType(.decimalPad)
                        if let halfLifeValidationMessage {
                            Text(halfLifeValidationMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Product", text: $productNameText)
                            .textInputAutocapitalization(.words)
                        if let productNameValidationMessage {
                            Text(productNameValidationMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Patient parameters")
                } footer: {
                    Text("These drive the pharmacokinetic estimate. Changing them recalculates the current level.")
                }
            }
            .navigationTitle("Edit profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
            }
        }
    }

    // MARK: - Parsing

    private var parsedWeight: Double? { ProfileEditParsing.parseWeight(weightText) }
    private var parsedBaseline: Double? { ProfileEditParsing.parseBaseline(baselineText) }
    private var parsedHalfLife: Double? { ProfileEditParsing.parseHalfLife(halfLifeText) }
    private var parsedProductName: String? { ProfileEditParsing.normalizedProductName(productNameText) }

    private var canSave: Bool {
        parsedWeight != nil && parsedBaseline != nil && parsedHalfLife != nil && parsedProductName != nil
    }

    // MARK: - Validation messages (shown only once the field is non-empty but invalid)

    private var weightValidationMessage: String? {
        guard !weightText.isEmpty, parsedWeight == nil else { return nil }
        return "Enter a weight greater than 0."
    }

    private var baselineValidationMessage: String? {
        guard !baselineText.isEmpty, parsedBaseline == nil else { return nil }
        return "Enter a baseline of 0 or more."
    }

    private var halfLifeValidationMessage: String? {
        guard !halfLifeText.isEmpty, parsedHalfLife == nil else { return nil }
        return "Enter a half-life greater than 0."
    }

    private var productNameValidationMessage: String? {
        guard !productNameText.isEmpty, parsedProductName == nil else { return nil }
        return "Enter a product name."
    }

    // MARK: - Save

    private func save() {
        guard let weight = parsedWeight,
              let baseline = parsedBaseline,
              let halfLife = parsedHalfLife,
              let productName = parsedProductName
        else { return }

        viewModel.updatePatientParameters(
            weightKg: weight != initialWeight ? weight : nil,
            baselinePercent: baseline != initialBaseline ? baseline : nil,
            halfLifeHours: halfLife != initialHalfLife ? halfLife : nil,
            productName: productName != initialProductName ? productName : nil
        )
        dismiss()
    }
}

#Preview {
    ProfileEditSheet(viewModel: FactorTrackerViewModel(settings: .defaultSettings))
}
