//
//  SheetChrome.swift
//  HEMOnitor
//

import SwiftUI

/// Shared bottom-sheet frame: grab handle, centred title, close button, and the
/// app's background gradient. Every sheet in the app wraps its content in this so
/// they read as one family rather than three separately-styled modals.
struct SheetChrome<Content: View>: View {
    let title: String
    var onClose: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(AppColor.ink.opacity(0.18))
                .frame(width: 38, height: 5)
                .padding(.top, 8)
                .accessibilityHidden(true)

            HStack {
                // Balances the close button so the title stays optically centred.
                Color.clear.frame(width: 34, height: 34)
                Spacer()
                Text(title)
                    .font(AppTextStyle.headline)
                    .foregroundStyle(AppColor.ink)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColor.inkSecondary)
                        .frame(width: 34, height: 34)
                        .background(AppColor.ink.opacity(0.07), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, Theme.Spacing.screenGutter)
            .padding(.top, 10)
            .padding(.bottom, 6)

            content()
        }
        .background(AppColor.backgroundGradient.ignoresSafeArea())
    }
}

/// A labelled row of computed values, used by the sheets to preview the effect of
/// what is about to be saved.
struct SheetSummaryRow: View {
    let label: String
    let value: String
    var emphasized: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(AppTextStyle.caption)
                .foregroundStyle(AppColor.inkSecondary)
            Spacer()
            Text(value)
                .font(.plexMono(emphasized ? 15 : 13, weight: .bold))
                .foregroundStyle(emphasized ? AppColor.primaryGreen : AppColor.ink)
        }
        .accessibilityElement(children: .combine)
    }
}
