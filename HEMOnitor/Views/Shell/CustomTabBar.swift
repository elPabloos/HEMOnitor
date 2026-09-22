//
//  CustomTabBar.swift
//  HEMOnitor
//

import SwiftUI

/// The glass pill bar from the design. Hand-rolled rather than a SwiftUI `TabView`
/// because the design's log button sits outside the bar and overlaps it, and because
/// the bar's translucent pill styling isn't reachable through `TabView` chrome.
///
/// Rolling our own means the accessibility `UITabBar` would have given us for free is
/// our responsibility instead: each item carries an explicit label, the `.isSelected`
/// trait, and a hit target at least 44pt tall.
struct CustomTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases) { tab in
                item(for: tab)
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 66)
        .background {
            Capsule()
                .fill(AppColor.glassFill)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .overlay {
            Capsule().strokeBorder(AppColor.glassBorder, lineWidth: 1)
        }
        .clipShape(Capsule())
        .themeShadow(.ambientCard)
        .accessibilityElement(children: .contain)
    }

    private func item(for tab: AppTab) -> some View {
        let isSelected = tab == selection

        return Button {
            guard !isSelected else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                selection = tab
            }
        } label: {
            VStack(spacing: 4) {
                Circle()
                    .fill(isSelected ? AppColor.primaryGreen : AppColor.ink.opacity(0.3))
                    .frame(width: 7, height: 7)

                Text(tab.title)
                    .font(.jakarta(11, weight: .bold))
                    .foregroundStyle(isSelected ? AppColor.primaryGreen : AppColor.inkSecondary)
            }
            .frame(maxWidth: .infinity)
            // 54pt clears the 44pt minimum hit target with room to spare.
            .frame(height: 54)
            .background {
                Capsule().fill(isSelected ? AppColor.primaryGreen.opacity(0.1) : .clear)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    @Previewable @State var selection: AppTab = .home
    return CustomTabBar(selection: $selection)
        .padding()
        .background(AppColor.backgroundGradient)
}
