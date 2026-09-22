//
//  Modifiers.swift
//  HEMOnitor
//

import SwiftUI

private struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat
    var strong: Bool
    var padding: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .padding(padding)
            .background {
                shape
                    .fill(strong ? AppColor.glassFillStrong : AppColor.glassFill)
                    .background(.ultraThinMaterial, in: shape)
            }
            .overlay {
                shape.strokeBorder(AppColor.glassBorder, lineWidth: 1)
            }
            .clipShape(shape)
            .themeShadow(.ambientCard)
    }
}

extension View {
    /// The "glass" card from the new design: translucent fill + Material, thin border, green-tinted shadow.
    func glassCard(cornerRadius: CGFloat = Theme.Radius.cardLarge, strong: Bool = false, padding: CGFloat = Theme.Spacing.cardPadding) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, strong: strong, padding: padding))
    }
}

/// Primary button: green pill with a CTA shadow — the mock's primary-action button.
struct PrimaryPillButtonStyle: ButtonStyle {
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.jakarta(16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(isDestructive ? AppColor.dangerForeground : AppColor.primaryGreen, in: Capsule())
            .themeShadow(isDestructive ? .ambientCard : .ctaGreen)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Secondary button: outlined pill, used for "Back"/"Cancel"-style actions.
struct SecondaryPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.jakarta(15, weight: .semiBold))
            .foregroundStyle(AppColor.inkSecondary)
            .padding(.horizontal, 22)
            .frame(height: 56)
            .background {
                Capsule().strokeBorder(AppColor.ink.opacity(0.14), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension ButtonStyle where Self == PrimaryPillButtonStyle {
    static var primaryPill: PrimaryPillButtonStyle { PrimaryPillButtonStyle() }
    static var destructivePill: PrimaryPillButtonStyle { PrimaryPillButtonStyle(isDestructive: true) }
}

extension ButtonStyle where Self == SecondaryPillButtonStyle {
    static var secondaryPill: SecondaryPillButtonStyle { SecondaryPillButtonStyle() }
}
