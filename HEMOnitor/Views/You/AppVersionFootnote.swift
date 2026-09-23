//
//  AppVersionFootnote.swift
//  HEMOnitor
//

import SwiftUI

/// Identifies the running build at the foot of the You screen, so a bug found while
/// testing on a real phone can be pinned to the task that produced it.
///
/// Its own view rather than a private property on `YouView` mainly so it has a
/// `#Preview`: it sits below the fold on the real screen, which makes it awkward to
/// check any other way.
struct AppVersionFootnote: View {
    var body: some View {
        Text(AppVersion.displayString)
            .font(AppTextStyle.monoLabel)
            .foregroundStyle(AppColor.inkTertiary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, Theme.Spacing.stackGapSmall)
            .accessibilityLabel(
                "App version \(AppVersion.shortVersion), build \(AppVersion.buildNumber), task \(AppVersion.latestTask)"
            )
    }
}

#Preview {
    ZStack {
        AppColor.backgroundGradient.ignoresSafeArea()
        AppVersionFootnote()
    }
}
