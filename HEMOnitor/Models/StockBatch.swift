//
//  StockBatch.swift
//  HEMOnitor
//

import Foundation

/// A batch of vials held in stock. Used by the Stock screen (a later phase);
/// the model is introduced now as part of the persistence layer.
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
