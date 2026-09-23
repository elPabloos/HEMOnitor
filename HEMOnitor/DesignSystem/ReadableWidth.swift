//
//  ReadableWidth.swift
//  HEMOnitor
//

import SwiftUI

/// Caps content width on regular-width devices (iPad, and iPhone landscape on the
/// larger models), centring it instead of letting it stretch edge to edge.
///
/// The app's layout is designed for a phone column: cards, a 250pt ring, and short
/// rows. Stretched across a 13" iPad those rows become metres-long label/value pairs
/// with the eye travelling the full width between them, and the glass cards lose the
/// proportions the design depends on. Constraining to a phone-ish column keeps one
/// layout working on both idioms — the alternative, a genuine split-view iPad layout,
/// is a redesign rather than a polish pass.
///
/// Compact width (every iPhone in portrait) is left completely untouched: the cap is
/// far wider than any phone, so this is a no-op there.
private struct ReadableWidthModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Roughly a large phone's width. Wide enough that nothing re-wraps compared to
    /// the phone layout, narrow enough that rows stay scannable.
    private let maxWidth: CGFloat = 480

    func body(content: Content) -> some View {
        if horizontalSizeClass == .regular {
            content
                .frame(maxWidth: maxWidth)
                .frame(maxWidth: .infinity)
        } else {
            content
        }
    }
}

extension View {
    /// Constrains this view to a readable column on regular-width devices. No-op on
    /// compact width.
    func readableWidth() -> some View {
        modifier(ReadableWidthModifier())
    }
}
