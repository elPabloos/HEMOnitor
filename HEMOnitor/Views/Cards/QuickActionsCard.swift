//
//  QuickActionsCard.swift
//  HEMOnitor
//

import SwiftUI

/// Cardul de acțiuni rapide: introducere doză (singurul punct de intrare spre
/// addInjection), deschidere calibrare, și vizualizare istoric complet.
struct QuickActionsCard: View {
    @Binding var doseText: String
    let parsedDoseIU: Double?
    let doseValidationMessage: String?
    let onAddInjection: () -> Void
    let onCalibrate: () -> Void
    let onViewHistory: () -> Void

    var body: some View {
        CardView {
            Text("Acțiuni rapide")
                .font(.headline)

            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    TextField("Doză (UI)", text: $doseText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)

                    Button("Adaugă injecție", action: onAddInjection)
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

            Button("Calibrare după analize", action: onCalibrate)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .background(Color.green.opacity(0.1))
                .cornerRadius(10)

            Button("Vezi tot istoricul", action: onViewHistory)
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
