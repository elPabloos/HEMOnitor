//
//  CardView.swift
//  HEMOnitor
//

import SwiftUI

/// Container reutilizabil pentru secțiunile de tip „card” din ecranul principal:
/// colțuri rotunjite, umbră discretă și fundal adaptiv (light/dark mode) prin
/// SwiftUI Material, opțional colorat cu o nuanță (ex. zona de siguranță).
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
