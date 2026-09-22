//
//  Typography.swift
//  HEMOnitor
//

import SwiftUI
import CoreText
import UIKit

/// Înregistrează la runtime fonturile aduse în bundle (Resources/Fonts), fără a
/// depinde de cheia Info.plist "Fonts provided by application" (UIAppFonts) — acest
/// proiect folosește un Info.plist generat din build settings, iar chei de tip
/// array nu pot fi adăugate acolo fără un Info.plist propriu. Înregistrarea prin
/// CTFontManagerRegisterFontsForURL este echivalentă din punct de vedere funcțional.
enum FontRegistrar {
    private static var didRegister = false

    /// Numele fișierelor (fără extensie) aduse în `Resources/Fonts`.
    private static let bundledFontFileNames = [
        "PlusJakartaSans[wght]",
        "IBMPlexMono-Regular",
        "IBMPlexMono-Medium"
    ]

    static func registerBundledFontsIfNeeded() {
        guard !didRegister else { return }
        didRegister = true

        for name in bundledFontFileNames {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
                assertionFailure("Font lipsă din bundle: \(name).ttf")
                continue
            }
            var error: Unmanaged<CFError>?
            let ok = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
            if !ok, let error {
                let nsError = error.takeRetainedValue() as Error as NSError
                // Deja înregistrat (ex. preview-uri re-rulate) — nu e o eroare reală.
                if nsError.code != CTFontManagerError.alreadyRegistered.rawValue {
                    assertionFailure("Nu am putut înregistra fontul \(name): \(nsError)")
                }
            }
        }
    }
}

/// Numele PostScript ale instanțelor de font disponibile după înregistrare.
/// Plus Jakarta Sans e adus ca variable font; numele instanțelor numite sunt cele
/// atribuite de Google Fonts (confirmate cu CTFontManagerCreateFontDescriptorsFromURL).
private enum FontName {
    static let jakartaRegular = "PlusJakartaSans-Regular"
    static let jakartaMedium = "PlusJakartaSans-Regular_Medium"
    static let jakartaSemiBold = "PlusJakartaSans-Regular_SemiBold"
    static let jakartaBold = "PlusJakartaSans-Regular_Bold"
    static let jakartaExtraBold = "PlusJakartaSans-Regular_ExtraBold"

    static let plexMonoRegular = "IBMPlexMono-Regular"
    static let plexMonoMedium = "IBMPlexMono-Medium"
}

enum AppFontWeight {
    case regular, medium, semiBold, bold, extraBold

    fileprivate var jakartaName: String {
        switch self {
        case .regular: return FontName.jakartaRegular
        case .medium: return FontName.jakartaMedium
        case .semiBold: return FontName.jakartaSemiBold
        case .bold: return FontName.jakartaBold
        case .extraBold: return FontName.jakartaExtraBold
        }
    }

    fileprivate var systemWeight: Font.Weight {
        switch self {
        case .regular: return .regular
        case .medium: return .medium
        case .semiBold: return .semibold
        case .bold: return .bold
        case .extraBold: return .heavy
        }
    }
}

extension Font {
    /// Plus Jakarta Sans — font de UI/body. Cade automat pe fontul de sistem dacă
    /// fontul n-a putut fi înregistrat (ex. înainte de primul apel al
    /// `FontRegistrar.registerBundledFontsIfNeeded()`, sau în teste).
    static func jakarta(_ size: CGFloat, weight: AppFontWeight = .regular) -> Font {
        guard UIFont(name: weight.jakartaName, size: size) != nil else {
            return .system(size: size, weight: weight.systemWeight, design: .rounded)
        }
        return .custom(weight.jakartaName, size: size)
    }

    /// IBM Plex Mono — folosit pentru toate valorile numerice (doze, procente, ore, loturi).
    static func plexMono(_ size: CGFloat, weight: AppFontWeight = .regular) -> Font {
        let name = weight == .medium || weight == .semiBold || weight == .bold || weight == .extraBold
            ? FontName.plexMonoMedium
            : FontName.plexMonoRegular
        guard UIFont(name: name, size: size) != nil else {
            return .system(size: size, weight: weight.systemWeight, design: .monospaced)
        }
        return .custom(name, size: size)
    }
}

/// Stiluri text semantice, dimensionate după machetă.
enum AppTextStyle {
    static var largeNumeral: Font { .jakarta(82, weight: .extraBold) }
    static var largeNumeralXL: Font { .jakarta(132, weight: .extraBold) }
    static var screenTitle: Font { .jakarta(23, weight: .extraBold) }
    static var onboardingTitle: Font { .jakarta(34, weight: .extraBold) }
    static var headline: Font { .jakarta(16.5, weight: .extraBold) }
    static var body: Font { .jakarta(15, weight: .regular) }
    static var bodyEmphasis: Font { .jakarta(14.5, weight: .bold) }
    static var caption: Font { .jakarta(12.5, weight: .medium) }
    static var kicker: Font { .jakarta(11.5, weight: .semiBold) }
    static var monoValue: Font { .plexMono(15, weight: .bold) }
    static var monoLabel: Font { .plexMono(12, weight: .medium) }
}
