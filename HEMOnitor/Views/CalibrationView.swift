//
//  CalibrationView.swift
//  HEMOnitor
//
//  Created by Ciudin, Paul-Catalin on 26.11.2025.
//

import SwiftUI

struct CalibrationView: View {
    @ObservedObject var viewModel: FactorTrackerViewModel
    
    @Environment(\.dismiss) private var dismiss
    
    // Form inputs
    @State private var doseText: String = ""
    @State private var observedPercentText: String = ""
    @State private var hoursText: String = "0.5"

    // Option B (PK): adjust recovery
    @State private var enableRecoveryAdjustment: Bool = false

    var body: some View {
        NavigationView {
            Form {
                // Quick guide
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What you'll need")
                            .font(.headline)
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Dose administered (IU)", systemImage: "checkmark.circle")
                            Label("Lab FVIII level (%)", systemImage: "checkmark.circle")
                            Label("Hours between dose and draw", systemImage: "checkmark.circle")
                        }
                        .font(.subheadline)

                        Divider().padding(.vertical, 4)

                        Text("Choosing an option")
                            .font(.headline)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("A) Display scaling (recommended): adjusts only what's shown, doesn't change the PK parameters.")
                            Text("B) Adjust recovery (PK parameter): changes how much REAL FVIII rises per 1 IU/kg, so the prediction matches the lab result. Use this when you want the REAL model to represent you more faithfully.")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                        Text("Note: you don't strictly need a \"before dose\" test. A single measurement a known number of hours after a known dose is enough.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Quick guide")
                }

                // Section: lab inputs
                Section {
                    TextField("Dose administered (IU)", text: $doseText)
                        .keyboardType(.numberPad)

                    TextField("Measured FVIII level (%)", text: $observedPercentText)
                        .keyboardType(.decimalPad)

                    TextField("Hours from injection to draw",
                              text: $hoursText)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("Lab result data")
                } footer: {
                    Text("Enter the dose administered, the measured FVIII percentage, and the time until the draw.")
                }

                // Section: calibration options (explanations for A and B)
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("A) Display scaling (recommended)")
                            .font(.headline)
                        Text("Matches the displayed level to the lab value, without changing the PK parameters (recovery). Values shown in the app will better reflect your reality.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)

                    Toggle(isOn: $enableRecoveryAdjustment) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("B) Adjust recovery (PK parameter)")
                                .font(.headline)
                            Text("Calibrates how much the REAL level rises per 1 IU/kg, so the model's prediction matches the (real) measurement. Use with care.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Calibration options")
                }

                // Section: action
                Section {
                    Button("Calibrate model") {
                        // Comma-tolerant parsing
                        let dose = Double(doseText.replacingOccurrences(of: ",", with: "."))
                        let observed = Double(observedPercentText.replacingOccurrences(of: ",", with: "."))
                        let hours = Double(hoursText.replacingOccurrences(of: ",", with: ".")) ?? 0.5

                        // Minimal validation
                        guard let dose, let observed, dose > 0, hours >= 0 else { return }

                        // Option A: display scaling (always)
                        viewModel.calibrateRecovery(
                            doseIU: dose,
                            observedPeakPercent: observed,
                            timeFromDoseHours: hours
                        )

                        // Option B: recovery adjustment (optional)
                        if enableRecoveryAdjustment {
                            viewModel.calibrateRecoveryParameter(
                                doseIU: dose,
                                observedDisplayPercent: observed,
                                timeFromDoseHours: hours
                            )
                        }

                        // Dismiss the sheet after calibrating
                        dismiss()
                    }
                    .disabled(doseText.isEmpty || observedPercentText.isEmpty)
                } footer: {
                    Text("Adjusting recovery (B) changes the PK parameter used to compute the REAL level. If you're not sure, leave only option A on.")
                }
            }
            .navigationTitle("FVIII Calibration")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    // Simple preview with a dummy viewModel
    var settings = AppSettings.defaultSettings
    settings.baselinePercent = 1
    return CalibrationView(viewModel: FactorTrackerViewModel(settings: settings))
}
