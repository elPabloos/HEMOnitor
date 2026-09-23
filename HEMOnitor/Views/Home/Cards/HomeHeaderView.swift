//
//  HomeHeaderView.swift
//  HEMOnitor
//

import SwiftUI

/// The custom Home header: an uppercase kicker greeting, the screen title,
/// and a glass capsule chip showing calibration status. Replaces
/// `navigationTitle` (`HomeView` no longer wraps in `NavigationStack`) so the
/// shell's background gradient shows through above the content, per the
/// design mock.
struct HomeHeaderView: View {
    let isCalibrated: Bool
    let onCalibrate: () -> Void

    /// At accessibility text sizes the title and the chip cannot share a row — the
    /// title wraps to three or four lines and the chip truncates to "No…". They stack
    /// instead, which costs vertical space only for the users who need it.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Theme.Spacing.stackGap) {
                    titleBlock
                    calibrationChip
                }
            } else {
                HStack(alignment: .center) {
                    titleBlock
                    Spacer()
                    calibrationChip
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting.uppercased())
                .font(AppTextStyle.kicker)
                .tracking(1.2)
                .foregroundStyle(AppColor.inkSecondary)
            Text("Factor Tracker")
                .font(AppTextStyle.screenTitle)
                .foregroundStyle(AppColor.ink)
                // Without this the title breaks mid-word ("Fact / or / Track / er").
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var calibrationChip: some View {
            Button(action: onCalibrate) {
                HStack(spacing: 6) {
                    Image(systemName: isCalibrated ? "checkmark.seal.fill" : "exclamationmark.circle")
                    Text(isCalibrated ? "Calibrated" : "Not calibrated")
                        .font(AppTextStyle.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(isCalibrated ? AppColor.primaryGreen : AppColor.warningForeground)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                // A fixed height truncated the label once the text scaled; a minimum
                // keeps the 44pt target without capping growth.
                .frame(minHeight: 40)
                .background {
                    Capsule().fill(AppColor.glassFill)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .overlay {
                    Capsule().strokeBorder(AppColor.glassBorder, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isCalibrated ? "Calibrated. Tap to recalibrate." : "Not calibrated. Tap to calibrate.")
    }
}

#Preview {
    VStack(spacing: 16) {
        HomeHeaderView(isCalibrated: false, onCalibrate: {})
        HomeHeaderView(isCalibrated: true, onCalibrate: {})
    }
    .padding()
    .background(AppColor.backgroundGradient)
}
