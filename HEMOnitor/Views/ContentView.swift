//
//  ContentView.swift
//  HEMOnitor
//
//  Created by Ciudin, Paul-Catalin on 05.08.2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: FactorTrackerViewModel
    @State private var showingCalibration = false
    
    // Simulare timp (doar cu butoane)
    @State private var simulatedOffsetHours: Double = 0
    
    // Alertă confirmare reset real
    @State private var showResetRealAlert = false
    
    // Timer: actualizează nivelul la fiecare 60 secunde
    private let timer = Timer
        .publish(every: 60, on: .main, in: .common)
        .autoconnect()
    
    init(
        viewModel: FactorTrackerViewModel = FactorTrackerViewModel(
            weightKg: 65,
            baselinePercent: 2,
            halfLifeHours: 19
        )
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Simulare timp – simplă, imediat sub titlu
                simulationSection
                
                // Nivel curent (afișat cu factorul de calibrare)
                VStack(spacing: 4) {
                    Text("Nivel curent estimat")
                        .font(.headline)
                    
                    Text(String(format: "%.1f %%", viewModel.currentDisplayLevelPercent))
                        .font(.system(size: 40, weight: .bold))
                    
                    Text("Valoare estimată pe baza dozelor și a timpului de înjumătățire. Nu înlocuiește analizele de laborator.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
                // Butoane rapide (fără reset aici)
                HStack(spacing: 12) {
                    Button("Injecție 3000 UI (test)") {
                        viewModel.addInjection(doseIU: 3000)
                        simulatedOffsetHours = 0
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                    
                    Button("Calibrare după analize") {
                        showingCalibration = true
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)
                }
                
                // Istoric injecții - full-width, fără fundal List
                if !viewModel.injections.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.injections.reversed()) { injection in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Doză: \(Int(injection.doseIU)) UI")
                                        .font(.headline)
                                    
                                    Text(String(
                                        format: "Nivel înainte: %.1f %%",
                                        injection.realLevelBefore
                                    ))
                                    
                                    Text(String(
                                        format: "Peak după: %.1f %%",
                                        injection.peakRealPercent
                                    ))
                                    
                                    Text(
                                        injection.date.formatted(
                                            date: .abbreviated,
                                            time: .shortened
                                        )
                                    )
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                            }
                        }
                        .padding(.horizontal)
                    }
                } else {
                    Text("Nicio injecție înregistrată încă.")
                        .foregroundColor(.secondary)
                        .padding(.top, 32)
                }
                
                // Buton Reset nivel (real) – la final, sub istoric
                Button(role: .destructive) {
                    showResetRealAlert = true
                } label: {
                    Text("Reset nivel (real)")
                        .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
                // Alertă de confirmare pentru reset real
                .alert("Ștergi istoricul și resetezi nivelul?",
                       isPresented: $showResetRealAlert) {
                    Button("Anulează", role: .cancel) { }
                    Button("Resetează", role: .destructive) {
                        viewModel.resetAll()
                        simulatedOffsetHours = 0
                    }
                } message: {
                    Text("Această acțiune va șterge toate injecțiile și va readuce nivelul la baseline.")
                }
                
                Spacer(minLength: 8)
            }
            .padding(.top)
            .navigationTitle("Factor Tracker")
            .onAppear {
                viewModel.recalculateLevels()
            }
            .onReceive(timer) { date in
                viewModel.recalculateLevels(at: date)
            }
            .sheet(isPresented: $showingCalibration) {
                CalibrationView(viewModel: viewModel)
            }
        }
    }
    
    // MARK: - Simulare UI (simplă)
    private var simulationSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Simulare timp")
                    .font(.headline)
                Spacer()
                if simulatedOffsetHours != 0 {
                    Button("Reset simulare") {
                        withAnimation { simulatedOffsetHours = 0 }
                    }
                }
            }
            
            // Valoare simulat + badge zile + dată/ora simulată
            let simulatedInfo = simulatedDisplayInfo()
            VStack(spacing: 6) {
                HStack {
                    Text(String(format: "Nivel simulat: %.1f %%", simulatedInfo.displayPercent))
                        .font(.title3).bold()
                    
                    if let daysText = simulatedDaysText() {
                        Text(daysText)
                            .font(.title3).bold()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.12))
                            .cornerRadius(6)
                    }
                    
                    Spacer()
                }
                
                Text("Ora simulată: \(simulatedInfo.simulatedDate.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(10)
            
            // Doar butoane de pas rapid
            HStack {
                Button("-24h") { stepSim(-24) }
                Spacer(minLength: 0)
                Button("+1h") { stepSim(+1) }
                Spacer(minLength: 0)
                Button("+6h") { stepSim(+6) }
                Spacer(minLength: 0)
                Button("+12h") { stepSim(+12) }
                Spacer(minLength: 0)
                Button("+24h") { stepSim(+24) }
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
    }
    
    // Returnează "Nd" dacă |offset| >= 24h, altfel nil
    private func simulatedDaysText() -> String? {
        let absHours = abs(simulatedOffsetHours)
        let days = Int(absHours / 24.0)
        guard days >= 1 else { return nil }
        return "\(days)d"
    }
    
    private func stepSim(_ hours: Double) {
        withAnimation {
            simulatedOffsetHours += hours
        }
    }
    
    // MARK: - Calcul nivel simulat (cu extrapolare înapoi)
    private func simulatedDisplayInfo() -> (displayPercent: Double, simulatedDate: Date) {
        let simulatedDate = Date().addingTimeInterval(simulatedOffsetHours * 3600)
        
        guard let last = viewModel.injections.last else {
            let real = viewModel.model.baselinePercent
            let display = viewModel.model.displayLevel(fromRealPercent: real)
            return (display, simulatedDate)
        }
        
        let hoursSincePeak = simulatedDate.timeIntervalSince(last.peakDate) / 3600.0
        let baseline = viewModel.model.baselinePercent
        let tHalf = max(viewModel.model.halfLifeHours, 0.0001)
        let peak = last.peakRealPercent
        
        let realAtSim: Double = {
            if hoursSincePeak >= 0 {
                return viewModel.model.levelAtTime(
                    peakPercent: peak,
                    hoursSincePeak: hoursSincePeak
                )
            } else {
                let infusion = max(0, (peak - baseline)) * pow(0.5, hoursSincePeak / tHalf)
                return min(peak, max(baseline, baseline + infusion))
            }
        }()
        
        let displayAtSim = viewModel.model.displayLevel(fromRealPercent: realAtSim)
        return (displayAtSim, simulatedDate)
    }
}

#Preview {
    ContentView()
}
