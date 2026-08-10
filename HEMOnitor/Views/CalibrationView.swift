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
    
    // Input-uri din formular
    @State private var doseText: String = ""
    @State private var observedPercentText: String = ""
    @State private var hoursText: String = "0.5"
    
    // Opțiunea B (PK): ajustarea recovery-ului
    @State private var enableRecoveryAdjustment: Bool = false
    
    var body: some View {
        NavigationView {
            Form {
                // Ghid rapid
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ce îți trebuie")
                            .font(.headline)
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Doza administrată (IU)", systemImage: "checkmark.circle")
                            Label("Nivel FVIII (%) din laborator", systemImage: "checkmark.circle")
                            Label("Ore între doză și recoltare", systemImage: "checkmark.circle")
                        }
                        .font(.subheadline)
                        
                        Divider().padding(.vertical, 4)
                        
                        Text("Cum aleg opțiunea")
                            .font(.headline)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("A) Scalare la afișare (recomandat): ajustează doar afișarea, nu schimbă parametrii PK.")
                            Text("B) Ajustează recovery (parametru PK): modifică cât crește REAL FVIII pentru 1 IU/kg, ca predicția să corespundă analizei. Folosește când vrei ca modelul REAL să te reprezinte mai fidel.")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        
                        Text("Notă: nu ai nevoie neapărat de o analiză „înainte de doză”. E suficientă o măsurătoare la un anumit număr de ore după o doză cunoscută.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Ghid rapid")
                }
                
                // Secțiune: intrări din laborator
                Section {
                    TextField("Doză administrată (IU)", text: $doseText)
                        .keyboardType(.numberPad)
                    
                    TextField("Nivel măsurat FVIII (%)", text: $observedPercentText)
                        .keyboardType(.decimalPad)
                    
                    TextField("Ore de la injecție până la recoltare",
                              text: $hoursText)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("Date din analiza de laborator")
                } footer: {
                    Text("Introdu doza administrată, procentul FVIII măsurat și intervalul de timp până la recoltare.")
                }
                
                // Secțiune: Opțiuni de calibrare (explicații A și B)
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("A) Scalare la afișare (recomandat)")
                            .font(.headline)
                        Text("Potrivește nivelul afișat cu valoarea din laborator, fără a schimba parametrii PK (recovery). Valorile afișate în app vor reflecta mai bine realitatea ta.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    Toggle(isOn: $enableRecoveryAdjustment) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("B) Ajustează recovery (parametru PK)")
                                .font(.headline)
                            Text("Calibrează cât crește nivelul REAL pentru 1 IU/kg, astfel încât predicția modelului să se potrivească măsurării (real). Folosește cu atenție.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Opțiuni de calibrare")
                }
                
                // Secțiune: acțiune
                Section {
                    Button("Calibrează modelul") {
                        // Parsing tolerant la virgulă
                        let dose = Double(doseText.replacingOccurrences(of: ",", with: "."))
                        let observed = Double(observedPercentText.replacingOccurrences(of: ",", with: "."))
                        let hours = Double(hoursText.replacingOccurrences(of: ",", with: ".")) ?? 0.5
                        
                        // Validare minimă
                        guard let dose, let observed, dose > 0, hours >= 0 else { return }
                        
                        // Opțiunea A: scalare la afișare (mereu)
                        viewModel.calibrateRecovery(
                            doseIU: dose,
                            observedPeakPercent: observed,
                            timeFromDoseHours: hours
                        )
                        
                        // Opțiunea B: ajustare recovery (opțional)
                        if enableRecoveryAdjustment {
                            viewModel.calibrateRecoveryParameter(
                                doseIU: dose,
                                observedDisplayPercent: observed,
                                timeFromDoseHours: hours
                            )
                        }
                        
                        // Închidem sheet-ul după calibrare
                        dismiss()
                    }
                    .disabled(doseText.isEmpty || observedPercentText.isEmpty)
                } footer: {
                    Text("Ajustarea recovery (B) schimbă parametrul PK folosit la calculul nivelului REAL. Dacă nu ești sigur, lasă doar opțiunea A activă.")
                }
            }
            .navigationTitle("Calibrare FVIII")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Închide") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    // Preview simplu cu un viewModel dummy
    let vm = FactorTrackerViewModel(
        weightKg: 65,
        baselinePercent: 1,
        halfLifeHours: 19
    )
    return CalibrationView(viewModel: vm)
}
