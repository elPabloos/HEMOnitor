//
//  QuickActionsCard.swift
//  HEMOnitor
//

import SwiftUI

/// The quick-actions card: dose entry (the sole entry point to addInjection),
/// opening calibration, and viewing the full history.
struct QuickActionsCard: View {
    @Binding var doseText: String
    let parsedDoseIU: Double?
    let doseValidationMessage: String?
    let onAddInjection: () -> Void
    let onCalibrate: () -> Void
    let onViewHistory: () -> Void

    var body: some View {
        CardView {
            Text("Quick actions")
                .font(.headline)

            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    TextField("Dose (IU)", text: $doseText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)

                    Button("Add injection", action: onAddInjection)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                        .disabled(parsedDoseIU == nil)
                }

                if let doseValidationMessage {
                    Text(doseValidationMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Button("Calibrate from lab results", action: onCalibrate)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .background(Color.green.opacity(0.1))
                .cornerRadius(10)

            Button("View full history", action: onViewHistory)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(10)
        }
    }
}

#Preview {
    QuickActionsCard(
        doseText: .constant(""),
        parsedDoseIU: nil,
        doseValidationMessage: nil,
        onAddInjection: {},
        onCalibrate: {},
        onViewHistory: {}
    )
    .padding()
}
