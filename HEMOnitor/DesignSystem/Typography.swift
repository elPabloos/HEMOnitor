//
//  Typography.swift
//  HEMOnitor
//

import SwiftUI
import CoreText
import UIKit

/// Registers the bundled fonts (Resources/Fonts) at runtime, without relying on
/// the Info.plist "Fonts provided by application" (UIAppFonts) key — this project
/// uses an Info.plist generated from build settings, and array-valued keys can't be
/// added there without introducing a standalone Info.plist. Registering via
/// CTFontManagerRegisterFontsForURL is functionally equivalent.
enum FontRegistrar {
    private static var didRegister = false

    /// The file names (without extension) bundled under `Resources/Fonts`.
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
                assertionFailure("Font missing from bundle: \(name).ttf")
                continue
            }
            var error: Unmanaged<CFError>?
            let ok = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
            if !ok, let error {
                let nsError = error.takeRetainedValue() as Error as NSError
                // Already registered (e.g. previews re-running) — not a real error.
                if nsError.code != CTFontManagerError.alreadyRegistered.rawValue {
                    assertionFailure("Could not register font \(name): \(nsError)")
                }
            }
        }
    }
}

/// PostScript names of the font instances available after registration.
/// Plus Jakarta Sans ships as a variable font; the named-instance names are the
/// ones assigned by Google Fonts (confirmed with CTFontManagerCreateFontDescriptorsFromURL).
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
    /// Plus Jakarta Sans — the UI/body font. Falls back to the system font if the
    /// font couldn't be registered (e.g. before the first call to
    /// `FontRegistrar.registerBundledFontsIfNeeded()`, or in tests).
    static func jakarta(_ size: CGFloat, weight: AppFontWeight = .regular) -> Font {
        guard UIFont(name: weight.jakartaName, size: size) != nil else {
            return .system(size: size, weight: weight.systemWeight, design: .rounded)
        }
        return .custom(weight.jakartaName, size: size)
    }

    /// IBM Plex Mono — used for all numeric values (doses, percentages, times, lot numbers).
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

/// Semantic text styles, sized to match the mock.
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
