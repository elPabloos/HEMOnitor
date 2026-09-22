//
//  ComingSoonView.swift
//  HEMOnitor
//

import SwiftUI

/// Placeholder for a tab whose screen hasn't been built yet. Each remaining screen
/// phase replaces its own case in `AppShellView.content`, so this view disappears on
/// its own as the rebuild finishes.
struct ComingSoonView: View {
    let tab: AppTab

    var body: some View {
        VStack(spacing: Theme.Spacing.stackGap) {
            Text(tab.title)
                .font(AppTextStyle.screenTitle)
                .foregroundStyle(AppColor.ink)

            Text("This screen hasn't been built yet.")
                .font(AppTextStyle.body)
                .foregroundStyle(AppColor.inkSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ComingSoonView(tab: .stock)
        .background(AppColor.backgroundGradient)
}
