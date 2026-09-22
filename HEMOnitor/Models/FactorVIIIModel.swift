//
//  FactorVIIIModel.swift
//  HEMOnitor
//
//  Created by Ciudin, Paul-Catalin on 24.11.2025.
//


import Foundation

/// Simple model for computing Factor VIII level over time.
/// WARNING: for visualization/tracking only, not for dosing decisions.
struct FactorVIIIModel {
    /// Weight, in kg
    var weightKg: Double

    /// The patient's "baseline" factor level, in %
    /// (e.g. 1.0 for a severe form)
    var baselinePercent: Double

    /// Half-life, in hours (default for Elocta ~19h)
    var halfLifeHours: Double = 19.0

    /// Recovery: how much FVIII rises, in %, per 1 IU/kg.
    /// Guidelines use ~2% / IU/kg for FVIII.
    var recoveryPercentPerIUPerKg: Double = 2.0

    /// Calibration factor for a personal "100%".
    /// If nil, no calibration is applied.
    var calibrationFactor: Double?

    // MARK: - Base functions

    /// Estimated rise in % from a given dose (excluding baseline).
    func deltaPercent(forDoseIU dose: Double) -> Double {
        guard weightKg > 0 else { return 0 }
        return (dose / weightKg) * recoveryPercentPerIUPerKg
    }

    /// The level immediately after an injection, in "real" (uncalibrated) %.
    func peakAfterDose(doseIU: Double,
                       currentLevelPercent: Double? = nil) -> Double {
        let delta = deltaPercent(forDoseIU: doseIU)
        let startLevel = currentLevelPercent ?? baselinePercent
        return startLevel + delta
    }

    /// The level over time, starting from a peak (peakPercent) at t0,
    /// after a number of elapsed hours.
    func levelAtTime(peakPercent: Double,
                     hoursSincePeak: Double) -> Double {
        guard hoursSincePeak >= 0, halfLifeHours > 0 else {
            return peakPercent
        }
        let infusionComponent = max(
            0,
            (peakPercent - baselinePercent)
                * pow(0.5, hoursSincePeak / halfLifeHours)
        )
        let total = baselinePercent + infusionComponent
        return max(baselinePercent, total)
    }

    /// Applies the calibration factor (if any) for display in the app.
    func displayLevel(fromRealPercent realPercent: Double) -> Double {
        guard let calibrationFactor else { return realPercent }
        return realPercent * calibrationFactor
    }

    /// Helper: the display level, starting from peak and elapsed hours.
    func displayLevel(peakPercent: Double,
                      hoursSincePeak: Double) -> Double {
        let real = levelAtTime(peakPercent: peakPercent,
                               hoursSincePeak: hoursSincePeak)
        return displayLevel(fromRealPercent: real)
    }

    // MARK: - Common operations

    /// First calibration: for a given dose (e.g. 3000 IU) we set "100%" in the app.
    func calibratedModel(forFirstDose doseIU: Double) -> FactorVIIIModel {
        let peak = peakAfterDose(doseIU: doseIU, currentLevelPercent: nil)
        let factor = peak == 0 ? nil : (100.0 / peak)
        var copy = self
        copy.calibrationFactor = factor
        return copy
    }

    /// Given a current (real) level and a new injection,
    /// returns the new REAL (uncalibrated) peak.
    func newPeakAfterAdditionalDose(doseIU: Double,
                                    currentRealLevelPercent: Double) -> Double {
        let delta = deltaPercent(forDoseIU: doseIU)
        return currentRealLevelPercent + delta
    }

    // MARK: - Calibration (Option A: display factor)
    /// Calibrates the display factor so the model's level at the draw time
    /// matches the percentage observed in the lab.
    mutating func calibrateRecovery(
        doseIU: Double,
        observedPeakPercent: Double,
        timeFromDoseHours: Double
    ) {
        let peakReal = peakAfterDose(doseIU: doseIU,
                                     currentLevelPercent: baselinePercent)
        let expectedRealAtLab = levelAtTime(peakPercent: peakReal,
                                            hoursSincePeak: timeFromDoseHours)
        if expectedRealAtLab > 0 {
            calibrationFactor = observedPeakPercent / expectedRealAtLab
        } else {
            calibrationFactor = nil
        }
    }

    // MARK: - Calibration (Option B: recovery)
    /// Adjusts recoveryPercentPerIUPerKg so the predicted REAL level at the draw time
    /// matches the observed REAL level.
    ///
    /// - Parameters:
    ///   - doseIU: the dose administered before the draw
    ///   - observedDisplayPercent: the observed percentage (a display-space value from the lab)
    ///   - timeFromDoseHours: hours between the dose and the draw
    ///
    /// Note: if a calibrationFactor exists, we convert it to real by dividing through it.
    mutating func calibrateRecoveryParameter(
        doseIU: Double,
        observedDisplayPercent: Double,
        timeFromDoseHours: Double
    ) {
        guard doseIU > 0, weightKg > 0 else { return }

        // Convert the observation to a REAL level (if a scaling factor exists)
        let observedReal: Double = {
            if let calibrationFactor, calibrationFactor > 0 {
                return observedDisplayPercent / calibrationFactor
            } else {
                return observedDisplayPercent
            }
        }()

        // Target: levelAtTime(baseline + infusionAtT0, hours) = observedReal
        // infusionNeededAtLab = observedReal - baseline
        let infusionNeededAtLab = max(0, observedReal - baselinePercent)

        // Inverse decay: infusionAtT0 = infusionNeededAtLab / 0.5^(h / t1/2)
        let decay = pow(0.5, timeFromDoseHours / max(halfLifeHours, 0.0001))
        let infusionAtT0 = infusionNeededAtLab / max(decay, 0.000001)

        // infusionAtT0 = (doseIU / weightKg) * recovery  => recovery = infusionAtT0 * weightKg / doseIU
        let newRecovery = infusionAtT0 * weightKg / doseIU

        // Apply a reasonable minimum bound for numerical stability
        if newRecovery.isFinite, newRecovery > 0 {
            recoveryPercentPerIUPerKg = newRecovery
        }
    }

    // MARK: - Threshold projection (user-defined)

    /// The inverse of `displayLevel(fromRealPercent:)`: converts a displayed
    /// percentage back to a real percentage, using the current calibrationFactor.
    func realPercent(fromDisplayPercent displayPercent: Double) -> Double {
        guard let calibrationFactor, calibrationFactor > 0 else { return displayPercent }
        return displayPercent / calibrationFactor
    }

    /// The number of hours until the current REAL level decays down to a target REAL
    /// threshold, using the same exponential curve as `levelAtTime` (the "memoryless"
    /// property of the decay). Returns nil if the threshold can't be reached via decay
    /// (current level at/below baseline, threshold at/below baseline, or threshold >= current level).
    func hoursUntilLevelReaches(
        targetRealPercent: Double,
        fromRealPercent currentRealPercent: Double
    ) -> Double? {
        guard halfLifeHours > 0,
              currentRealPercent > baselinePercent,
              targetRealPercent > baselinePercent,
              targetRealPercent < currentRealPercent
        else {
            return nil
        }
        let ratio = (targetRealPercent - baselinePercent) / (currentRealPercent - baselinePercent)
        guard ratio > 0 else { return nil }
        return halfLifeHours * log2(1 / ratio)
    }
}
