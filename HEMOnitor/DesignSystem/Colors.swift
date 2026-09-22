//
//  Colors.swift
//  HEMOnitor
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

private extension Color {
    /// A dynamic light/dark color, without depending on Asset Catalog color sets.
    init(light: Color, dark: Color) {
        #if canImport(UIKit)
        self = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #else
        self = light
        #endif
    }

    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

/// The new design's color palette ("Mobile app design project"), plus a dark
/// variant added to preserve the dark-mode support the app gets today via
/// Material. The original mocks are light-only — the dark values below are
/// derived for contrast, not taken 1:1 from the mock.
enum AppColor {
    // MARK: Fundal

    static let backgroundTop = Color(light: Color(hex: 0xEAF1E7), dark: Color(hex: 0x0F1712))
    static let backgroundMid = Color(light: Color(hex: 0xDCEADE), dark: Color(hex: 0x131F18))
    static let backgroundBottom = Color(light: Color(hex: 0xCFE2D9), dark: Color(hex: 0x16231B))

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [backgroundTop, backgroundMid, backgroundBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: Text / ink

    static let ink = Color(light: Color(hex: 0x16231B), dark: Color(hex: 0xEAF1E7))
    static let inkSecondary = ink.opacity(0.64)
    static let inkTertiary = ink.opacity(0.5)

    // MARK: Brand

    static let primaryGreen = Color(light: Color(hex: 0x2F5C3F), dark: Color(hex: 0x5FAE7C))
    static let accentGreen = Color(light: Color(hex: 0x4C8058), dark: Color(hex: 0x7BC492))

    static var brandGradient: LinearGradient {
        LinearGradient(colors: [primaryGreen, accentGreen], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: Zone (folosite de SafetyZone)

    static let zoneCritical = Color(light: Color(hex: 0x7D3226), dark: Color(hex: 0xC85A48))
    static let zoneLow = Color(light: Color(hex: 0xA8483A), dark: Color(hex: 0xD97362))
    static let zonePartial = Color(light: Color(hex: 0xA8762A), dark: Color(hex: 0xD9A04C))
    static let zoneWellCovered = Color(light: Color(hex: 0x4C8058), dark: Color(hex: 0x5FAE7C))
    static let zoneAboveNormal = Color(light: Color(hex: 0x3F6FA8), dark: Color(hex: 0x6F9BD9))

    // MARK: Glass (carduri translucide)

    static let glassFill = Color(light: Color.white.opacity(0.72), dark: Color.white.opacity(0.08))
    static let glassFillStrong = Color(light: Color.white.opacity(0.85), dark: Color.white.opacity(0.12))
    static let glassBorder = Color(light: Color.white.opacity(0.85), dark: Color.white.opacity(0.16))

    // MARK: States

    static let warningBackground = Color(light: Color(hex: 0xFFF7E8, opacity: 0.85), dark: Color(hex: 0x2A2110, opacity: 0.85))
    static let warningForeground = Color(light: Color(hex: 0x7D5A1C), dark: Color(hex: 0xE0B667))

    static let dangerBackground = Color(light: Color(hex: 0xA8483A, opacity: 0.07), dark: Color(hex: 0xD97362, opacity: 0.12))
    static let dangerForeground = Color(light: Color(hex: 0xA8483A), dark: Color(hex: 0xD97362))
}
