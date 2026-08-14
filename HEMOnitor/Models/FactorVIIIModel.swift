//
//  FactorVIIIModel.swift
//  HEMOnitor
//
//  Created by Ciudin, Paul-Catalin on 24.11.2025.
//


import Foundation

/// Model simplu pentru calculul nivelului de factor VIII în timp.
/// ATENȚIE: doar pentru vizualizare / tracking, nu pentru decizii de dozaj.
struct FactorVIIIModel {
    /// Greutate în kg
    var weightKg: Double
    
    /// Nivelul de factor „de bază” al pacientului, în %
    /// (ex: 1.0 pentru formă severă)
    var baselinePercent: Double
    
    /// Half-life în ore (default pentru Elocta ~19h)
    var halfLifeHours: Double = 19.0
    
    /// Recovery: cât % crește FVIII pentru 1 IU/kg.
    /// Ghidurile folosesc ~2% / IU/kg pentru FVIII.
    var recoveryPercentPerIUPerKg: Double = 2.0
    
    /// Factorul de calibrare pentru "100%" personal.
    /// Dacă e nil, nu se aplică calibrare.
    var calibrationFactor: Double?
    
    // MARK: - Funcții de bază
    
    /// Creșterea estimată în % de la o doză dată (fără baseline).
    func deltaPercent(forDoseIU dose: Double) -> Double {
        guard weightKg > 0 else { return 0 }
        return (dose / weightKg) * recoveryPercentPerIUPerKg
    }
    
    /// Nivelul imediat după o injecție, în % „reale” (necalibrate).
    func peakAfterDose(doseIU: Double,
                       currentLevelPercent: Double? = nil) -> Double {
        let delta = deltaPercent(forDoseIU: doseIU)
        let startLevel = currentLevelPercent ?? baselinePercent
        return startLevel + delta
    }
    
    /// Nivelul în timp, pornind de la un vârf (peakPercent) la momentul t0,
    /// după un număr de ore trecute.
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
    
    /// Aplică factorul de calibrare (dacă există) pentru afișare în app.
    func displayLevel(fromRealPercent realPercent: Double) -> Double {
        guard let calibrationFactor else { return realPercent }
        return realPercent * calibrationFactor
    }
    
    /// Helper: nivel de afișat, pornind de la peak și ore trecute.
    func displayLevel(peakPercent: Double,
                      hoursSincePeak: Double) -> Double {
        let real = levelAtTime(peakPercent: peakPercent,
                               hoursSincePeak: hoursSincePeak)
        return displayLevel(fromRealPercent: real)
    }
    
    // MARK: - Operații uzuale
    
    /// Prima calibrare: pentru o doză (ex. 3000 IU) setăm "100%" în app.
    func calibratedModel(forFirstDose doseIU: Double) -> FactorVIIIModel {
        let peak = peakAfterDose(doseIU: doseIU, currentLevelPercent: nil)
        let factor = peak == 0 ? nil : (100.0 / peak)
        var copy = self
        copy.calibrationFactor = factor
        return copy
    }
    
    /// Când ai un nivel curent (real) și faci o nouă injecție,
    /// întoarce noul peak REAL (necalibrat).
    func newPeakAfterAdditionalDose(doseIU: Double,
                                    currentRealLevelPercent: Double) -> Double {
        let delta = deltaPercent(forDoseIU: doseIU)
        return currentRealLevelPercent + delta
    }
    
    // MARK: - Calibrare (Opțiunea A: factor de afișare)
    /// Calibrează factorul de afișare astfel încât nivelul modelului la timpul de recoltare
    /// să corespundă procentului observat în laborator.
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
    
    // MARK: - Calibrare (Opțiunea B: recovery)
    /// Ajustează recoveryPercentPerIUPerKg astfel încât nivelul REAL prezis la timpul de recoltare
    /// să corespundă nivelului REAL observat.
    ///
    /// - Parameters:
    ///   - doseIU: doza administrată înainte de recoltare
    ///   - observedDisplayPercent: procentul observat (valoare de afișat din laborator)
    ///   - timeFromDoseHours: orele dintre doză și recoltare
    ///
    /// Observație: dacă există calibrationFactor, convertim la real prin împărțire.
    mutating func calibrateRecoveryParameter(
        doseIU: Double,
        observedDisplayPercent: Double,
        timeFromDoseHours: Double
    ) {
        guard doseIU > 0, weightKg > 0 else { return }
        
        // Convertim observația la nivel REAL (dacă există factor de scalare)
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
        
        // Decădere inversă: infusionAtT0 = infusionNeededAtLab / 0.5^(h / t1/2)
        let decay = pow(0.5, timeFromDoseHours / max(halfLifeHours, 0.0001))
        let infusionAtT0 = infusionNeededAtLab / max(decay, 0.000001)
        
        // infusionAtT0 = (doseIU / weightKg) * recovery  => recovery = infusionAtT0 * weightKg / doseIU
        let newRecovery = infusionAtT0 * weightKg / doseIU
        
        // Aplicăm o limită minimă rezonabilă pentru stabilitate numerică
        if newRecovery.isFinite, newRecovery > 0 {
            recoveryPercentPerIUPerKg = newRecovery
        }
    }

    // MARK: - Proiecție prag (definit de utilizator)

    /// Inversul lui `displayLevel(fromRealPercent:)`: convertește un procent afișat
    /// înapoi în procent real, folosind calibrationFactor curent.
    func realPercent(fromDisplayPercent displayPercent: Double) -> Double {
        guard let calibrationFactor, calibrationFactor > 0 else { return displayPercent }
        return displayPercent / calibrationFactor
    }

    /// Numărul de ore până când nivelul REAL curent ajunge (prin decădere) la un prag REAL țintă,
    /// folosind aceeași curbă exponențială ca `levelAtTime` (proprietatea „memoryless” a decăderii).
    /// Returnează nil dacă pragul nu poate fi atins prin decădere (nivel curent sub/la baseline,
    /// prag sub/la baseline, sau prag >= nivelul curent).
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

