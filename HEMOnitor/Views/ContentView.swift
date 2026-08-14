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
    @State private var showingHistory = false

    // Doza introdusă de utilizator, în UI (unități internaționale)
    @State private var doseText: String = ""

    // Pragul introdus de utilizator pentru proiecția din NextDoseCard
    @State private var targetThresholdText: String = ""

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
            ScrollView {
                VStack(spacing: 16) {
                    // Simulare timp – control compact, imediat sub titlu
                    simulationControlsCard

                    let simulatedInfo = simulatedDisplayInfo()
                    CurrentLevelCard(
                        realDisplayPercent: viewModel.currentDisplayLevelPercent,
                        isSimulated: simulatedOffsetHours != 0,
                        simulatedDisplayPercent: simulatedInfo.displayPercent,
                        simulatedDate: simulatedInfo.simulatedDate,
                        simulatedDaysText: simulatedDaysText()
                    )

                    NextDoseCard(
                        model: viewModel.model,
                        currentRealPercent: viewModel.currentRealLevelPercent,
                        targetText: $targetThresholdText
                    )

                    LastInjectionCard(
                        model: viewModel.model,
                        lastInjection: viewModel.injections.last
                    )

                    QuickActionsCard(
                        doseText: $doseText,
                        parsedDoseIU: parsedDoseIU,
                        doseValidationMessage: doseValidationMessage,
                        onAddInjection: addInjectionFromInput,
                        onCalibrate: { showingCalibration = true },
                        onViewHistory: { showingHistory = true }
                    )

                    // Buton Reset nivel (real) – la final, sub carduri
                    Button(role: .destructive) {
                        showResetRealAlert = true
                    } label: {
                        Text("Reset nivel (real)")
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
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
                }
                .padding(.horizontal)
                .padding(.top)
            }
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
            .sheet(isPresented: $showingHistory) {
                historySheet
            }
        }
    }

    // MARK: - Doză introdusă de utilizator

    /// Doza validată din câmpul de text, sau nil dacă intrarea nu e utilizabilă.
    /// Parsing tolerant la virgulă, ca în CalibrationView.
    private var parsedDoseIU: Double? {
        let normalized = doseText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard let dose = Double(normalized), dose.isFinite, dose > 0 else {
            return nil
        }
        return dose
    }

    /// Mesaj afișat doar când utilizatorul a scris ceva, dar doza nu e validă.
    private var doseValidationMessage: String? {
        guard !doseText.isEmpty, parsedDoseIU == nil else { return nil }
        return "Introdu o doză validă, mai mare decât 0."
    }

    private func addInjectionFromInput() {
        guard let dose = parsedDoseIU else { return }
        viewModel.addInjection(doseIU: dose)
        simulatedOffsetHours = 0
        doseText = ""
    }

    // MARK: - Istoric complet (sheet)
    private var historySheet: some View {
        NavigationView {
            Group {
                if viewModel.injections.isEmpty {
                    Text("Nicio injecție înregistrată încă.")
                        .foregroundColor(.secondary)
                        .padding(.top, 32)
                } else {
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
                }
            }
            .navigationTitle("Istoric injecții")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Închide") {
                        showingHistory = false
                    }
                }
            }
        }
    }

    // MARK: - Simulare UI (control compact)
    private var simulationControlsCard: some View {
        CardView {
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
