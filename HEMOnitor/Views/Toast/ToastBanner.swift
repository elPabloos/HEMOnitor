//
//  ToastBanner.swift
//  HEMOnitor
//

import SwiftUI

struct ToastBanner: View {
    let toast: Toast

    var body: some View {
        HStack(spacing: Theme.Spacing.stackGap) {
            Image(systemName: toast.kind.iconSystemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(toast.kind.tint)

            Text(toast.message)
                .font(.jakarta(14, weight: .semiBold))
                .foregroundStyle(AppColor.ink)
                .multilineTextAlignment(.leading)
                .lineLimit(3)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 16)
        .glassCard(cornerRadius: Theme.Radius.card, strong: true, padding: 0)
        .accessibilityElement(children: .combine)
    }
}

private struct ToastHostModifier: ViewModifier {
    @ObservedObject var presenter: ToastPresenter

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let toast = presenter.current {
                ToastBanner(toast: toast)
                    .padding(.top, Theme.Spacing.stackGap)
                    .padding(.horizontal, Theme.Spacing.screenGutter)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { presenter.dismiss() }
                    .zIndex(100)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: presenter.current)
    }
}

extension View {
    /// Attaches a toast overlay at the top of the screen, driven by `presenter`.
    func toastHost(_ presenter: ToastPresenter) -> some View {
        modifier(ToastHostModifier(presenter: presenter))
    }
}

#Preview {
    let presenter = ToastPresenter()
    return VStack {
        Button("Show success") { presenter.show("Injection added", kind: .success) }
        Button("Show error") { presenter.show("Not enough vials in stock", kind: .error) }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(AppColor.backgroundGradient)
    .toastHost(presenter)
}
