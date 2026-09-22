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

    // User-entered dose, in IU (international units)
    @State private var doseText: String = ""

    // User-entered threshold for the NextDoseCard projection
    @State private var targetThresholdText: String = ""

    // Time simulation (buttons only)
    @State private var simulatedOffsetHours: Double = 0

    // Real-reset confirmation alert
    @State private var showResetRealAlert = false

    // Timer: refreshes the level every 60 seconds
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
                    // Time simulation – compact control, right under the title
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

                    // Reset (real) level button – at the end, below the cards
                    Button(role: .destructive) {
                        showResetRealAlert = true
                    } label: {
                        Text("Reset level (real)")
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
                    // Confirmation alert for the real reset
                    .alert("Clear history and reset the level?",
                           isPresented: $showResetRealAlert) {
                        Button("Cancel", role: .cancel) { }
                        Button("Reset", role: .destructive) {
                            viewModel.resetAll()
                            simulatedOffsetHours = 0
                        }
                    } message: {
                        Text("This will delete all injections and return the level to baseline.")
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

    // MARK: - User-entered dose

    /// The validated dose from the text field, or nil if the input isn't usable.
    /// Comma-tolerant parsing, same as CalibrationView.
    private var parsedDoseIU: Double? {
        let normalized = doseText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard let dose = Double(normalized), dose.isFinite, dose > 0 else {
            return nil
        }
        return dose
    }

    /// Shown only once the user has typed something, but the dose isn't valid.
    private var doseValidationMessage: String? {
        guard !doseText.isEmpty, parsedDoseIU == nil else { return nil }
        return "Enter a valid dose greater than 0."
    }

    private func addInjectionFromInput() {
        guard let dose = parsedDoseIU else { return }
        viewModel.addInjection(doseIU: dose)
        simulatedOffsetHours = 0
        doseText = ""
    }

    // MARK: - Full history (sheet)
    private var historySheet: some View {
        NavigationView {
            Group {
                if viewModel.injections.isEmpty {
                    Text("No injection recorded yet.")
                        .foregroundColor(.secondary)
                        .padding(.top, 32)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.injections.reversed()) { injection in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Dose: \(Int(injection.doseIU)) IU")
                                        .font(.headline)

                                    Text(String(
                                        format: "Level before: %.1f %%",
                                        injection.realLevelBefore
                                    ))

                                    Text(String(
                                        format: "Peak after: %.1f %%",
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
            .navigationTitle("Injection history")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        showingHistory = false
                    }
                }
            }
        }
    }

    // MARK: - Simulation controls (compact)
    private var simulationControlsCard: some View {
        CardView {
            HStack {
                Text("Time simulation")
                    .font(.headline)
                Spacer()
                if simulatedOffsetHours != 0 {
                    Button("Reset simulation") {
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

    // Returns "Nd" if |offset| >= 24h, otherwise nil
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

    // MARK: - Simulated level calculation (with backward extrapolation)
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
