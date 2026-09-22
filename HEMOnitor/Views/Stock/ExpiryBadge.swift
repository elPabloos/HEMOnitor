//
//  ExpiryBadge.swift
//  HEMOnitor
//

import SwiftUI

/// How urgently a lot needs to be used before it expires. Purely a display
/// concern — not stored on `StockBatch` — so it's derived fresh each render
/// from `expiryDate` and the current date.
enum StockExpiryUrgency {
    case expired
    case expiringSoon
    case normal

    /// A lot within this many days of expiry (but not yet expired) is "soon".
    static let soonThresholdDays = 30

    init(expiryDate: Date, referenceDate: Date = Date()) {
        let days = Calendar.current.dateComponents([.day], from: referenceDate, to: expiryDate).day ?? 0
        if expiryDate < referenceDate {
            self = .expired
        } else if days <= Self.soonThresholdDays {
            self = .expiringSoon
        } else {
            self = .normal
        }
    }

    var foreground: Color {
        switch self {
        case .expired: return AppColor.dangerForeground
        case .expiringSoon: return AppColor.warningForeground
        case .normal: return AppColor.primaryGreen
        }
    }

    var background: Color {
        switch self {
        case .expired: return AppColor.dangerBackground
        case .expiringSoon: return AppColor.warningBackground
        case .normal: return AppColor.primaryGreen.opacity(0.1)
        }
    }

    var symbolName: String {
        switch self {
        case .expired: return "exclamationmark.triangle.fill"
        case .expiringSoon: return "clock.fill"
        case .normal: return "checkmark.seal.fill"
        }
    }

    var accessibilityPrefix: String {
        switch self {
        case .expired: return "Expired"
        case .expiringSoon: return "Expiring soon"
        case .normal: return "Expires"
        }
    }
}

/// A small pill showing a lot's expiry date, colored by how urgently it needs
/// to be used (`StockExpiryUrgency`).
struct ExpiryBadge: View {
    let expiryDate: Date

    private var urgency: StockExpiryUrgency { StockExpiryUrgency(expiryDate: expiryDate) }

    private var dateText: String {
        expiryDate.formatted(.dateTime.day().month(.abbreviated).year(.twoDigits))
    }

    var body: some View {
        Label {
            Text(dateText)
                .font(AppTextStyle.monoLabel)
        } icon: {
            Image(systemName: urgency.symbolName)
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(urgency.foreground)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(urgency.background, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(urgency.accessibilityPrefix) \(dateText)")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        ExpiryBadge(expiryDate: Date().addingTimeInterval(-86400 * 3))
        ExpiryBadge(expiryDate: Date().addingTimeInterval(86400 * 10))
        ExpiryBadge(expiryDate: Date().addingTimeInterval(86400 * 200))
    }
    .padding()
    .background(AppColor.backgroundGradient)
}
