//
//  FloatingLogButton.swift
//  HEMOnitor
//

import SwiftUI

/// The circular "+" beside the tab bar. It opens the log sheet without changing the
/// selected tab, which is why it is a sibling of the bar rather than a fifth item in it.
struct FloatingLogButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 66, height: 66)
                .background(AppColor.primaryGreen, in: Circle())
                .themeShadow(.ctaGreen)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log a dose")
        .accessibilityHint("Opens the dose logging sheet")
    }
}

#Preview {
    FloatingLogButton(action: {})
        .padding()
        .background(AppColor.backgroundGradient)
}
