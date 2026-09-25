//
//  HomeRadius.swift
//  HEMOnitor
//

import SwiftUI

/// Corner radii for the Home screen, each 5pt tighter than the app-wide value in
/// `Theme.Radius`.
///
/// Home-scoped on purpose: this is a trial of a tighter corner treatment, and the rest
/// of the app still uses `Theme.Radius` until the reduction is approved everywhere. If
/// it is, the new values move into `Theme.Radius` and this type is deleted rather than
/// being left as a second source of truth.
///
/// Capsules are untouched — they are fully rounded by definition, so "5pt tighter"
/// has no meaning for them.
enum HomeRadius {
    /// `Theme.Radius.card` (22) minus 5.
    static let card: CGFloat = Theme.Radius.card - 5

    /// `Theme.Radius.cardLarge` (24) minus 5 — the default `glassCard()` radius.
    static let cardLarge: CGFloat = Theme.Radius.cardLarge - 5
}
