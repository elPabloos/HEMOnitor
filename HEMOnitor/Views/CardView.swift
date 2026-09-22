//
//  CardView.swift
//  HEMOnitor
//

import SwiftUI

/// Reusable container for the "card" sections on the main screen: rounded
/// corners, a subtle shadow, and a light/dark-adaptive background via SwiftUI
/// Material, optionally tinted (e.g. by safety zone).
struct CardView<Content: View>: View {
    var tint: Color? = nil
    @ViewBuilder var content: () -> Content

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 16, style: .continuous) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background {
            shape
                .fill((tint ?? .clear).opacity(0.15))
                .background(.regularMaterial, in: shape)
        }
        .clipShape(shape)
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
    }
}
