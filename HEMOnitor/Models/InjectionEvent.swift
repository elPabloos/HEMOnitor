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

    /// Vial lot this dose came from, when it was logged against stock. `nil` for a
    /// manually entered dose, which has no batch behind it.
    ///
    /// Optional so the synthesised decoder uses `decodeIfPresent` and state saved
    /// before this field existed still loads — see the decode-default rule in the
    /// redesign plan.
    let lot: String?

    /// Product this dose was given from. `nil` means "whatever the patient's current
    /// product is", so historical events don't silently claim a product that was
    /// never recorded; callers fall back to `AppSettings.productName`.
    let productName: String?

    /// For compatibility, peakDate = the injection date
    var peakDate: Date { date }

    init(
        id: UUID,
        date: Date,
        doseIU: Double,
        realLevelBefore: Double,
        peakRealPercent: Double,
        lot: String? = nil,
        productName: String? = nil
    ) {
        self.id = id
        self.date = date
        self.doseIU = doseIU
        self.realLevelBefore = realLevelBefore
        self.peakRealPercent = peakRealPercent
        self.lot = lot
        self.productName = productName
    }
}
#if DEBUG
extension InjectionEvent: CustomStringConvertible {
    var description: String {
        "\(date): \(doseIU) IU, realLevelBefore: \(realLevelBefore), peakRealPercent: \(peakRealPercent)"
    }
}
#endif
