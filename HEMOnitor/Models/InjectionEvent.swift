//
//  InjectionEvent.swift
//  HEMOnitor
//
//  Created by Ciudin, Paul-Catalin on 24.11.2025.
//

import Foundation

struct InjectionEvent: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let date: Date
    let doseIU: Double
    
    /// The estimated real (uncalibrated) level right before the injection
    let realLevelBefore: Double

    /// The new real (uncalibrated) peak right after the injection
    let peakRealPercent: Double

    /// For compatibility, peakDate = the injection date
    var peakDate: Date { date }
}
#if DEBUG
extension InjectionEvent: CustomStringConvertible {
    var description: String {
        "\(date): \(doseIU) IU, realLevelBefore: \(realLevelBefore), peakRealPercent: \(peakRealPercent)"
    }
}
#endif
