//
//  InjectionEvent.swift
//  HEMOnitor
//
//  Created by Ciudin, Paul-Catalin on 24.11.2025.
//

import Foundation

struct InjectionEvent: Identifiable {
    let id: UUID
    let date: Date
    let doseIU: Double
    
    /// Nivelul real (necalibrat) estimat chiar înainte de injecție
    let realLevelBefore: Double
    
    /// Noul peak real (necalibrat) imediat după injecție
    let peakRealPercent: Double
    
    /// Pentru compatibilitate, peakDate = data injecției
    var peakDate: Date { date }
}
#if DEBUG
extension InjectionEvent: CustomStringConvertible {
    var description: String {
        "\(date): \(doseIU) IU, realLevelBefore: \(realLevelBefore), peakRealPercent: \(peakRealPercent)"
    }
}
#endif
