//
//  StockBatch.swift
//  HEMOnitor
//

import Foundation

/// Un lot de flacoane aflat în stoc. Folosit de ecranul Stock (fază ulterioară);
/// modelul e introdus acum ca parte a stratului de persistență.
struct StockBatch: Codable, Equatable, Identifiable {
    let id: UUID
    var productName: String
    var lotNumber: String
    var expiryDate: Date
    var vialSizeIU: Double
    var quantity: Int
    var dateAdded: Date

    init(
        id: UUID = UUID(),
        productName: String,
        lotNumber: String,
        expiryDate: Date,
        vialSizeIU: Double,
        quantity: Int,
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.productName = productName
        self.lotNumber = lotNumber
        self.expiryDate = expiryDate
        self.vialSizeIU = vialSizeIU
        self.quantity = quantity
        self.dateAdded = dateAdded
    }
}
