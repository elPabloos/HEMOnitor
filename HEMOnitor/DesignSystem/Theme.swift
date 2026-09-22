//
//  Theme.swift
//  HEMOnitor
//

import SwiftUI

/// Constante de spațiere, raze de colț și umbre pentru noul limbaj vizual,
/// preluate din machetele de design (paleta glass/pill din "Mobile app design project").
enum Theme {
    enum Spacing {
        /// Gutter-ul standard de ecran.
        static let screenGutter: CGFloat = 22
        static let cardPadding: CGFloat = 18
        static let cardPaddingCompact: CGFloat = 14
        static let stackGapLarge: CGFloat = 16
        static let stackGap: CGFloat = 10
        static let stackGapSmall: CGFloat = 8
    }

    enum Radius {
        /// Butoane, chip-uri, toggle-uri — complet rotunjite.
        static let pill: CGFloat = 99
        static let card: CGFloat = 22
        static let cardLarge: CGFloat = 24
        static let input: CGFloat = 17
        static let sheetTop: CGFloat = 30
    }

    enum ShadowStyle {
        case ambientCard
        case ctaGreen
        case sheet

        var color: Color {
            switch self {
            case .ambientCard: return Color(red: 31/255, green: 58/255, blue: 40/255).opacity(0.07)
            case .ctaGreen: return Color(red: 47/255, green: 92/255, blue: 63/255).opacity(0.32)
            case .sheet: return Color(red: 16/255, green: 32/255, blue: 22/255).opacity(0.25)
            }
        }

        var radius: CGFloat {
            switch self {
            case .ambientCard: return 20
            case .ctaGreen: return 26
            case .sheet: return 36
            }
        }

        var offset: CGSize {
            switch self {
            case .ambientCard: return CGSize(width: 0, height: 6)
            case .ctaGreen: return CGSize(width: 0, height: 11)
            case .sheet: return CGSize(width: 0, height: -12)
            }
        }
    }
}

extension View {
    /// Umbra difuză, verzuie, folosită sub carduri/butoane în noul design.
    func themeShadow(_ style: Theme.ShadowStyle) -> some View {
        shadow(color: style.color, radius: style.radius, x: style.offset.width, y: style.offset.height)
    }
}
