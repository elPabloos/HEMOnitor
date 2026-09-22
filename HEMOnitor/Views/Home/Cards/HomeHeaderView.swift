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

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting.uppercased())
                    .font(AppTextStyle.kicker)
                    .tracking(1.2)
                    .foregroundStyle(AppColor.inkSecondary)
                Text("Factor Tracker")
                    .font(AppTextStyle.screenTitle)
                    .foregroundStyle(AppColor.ink)
            }

            Spacer()

            Button(action: onCalibrate) {
                HStack(spacing: 6) {
                    Image(systemName: isCalibrated ? "checkmark.seal.fill" : "exclamationmark.circle")
                    Text(isCalibrated ? "Calibrated" : "Not calibrated")
                        .font(AppTextStyle.caption)
                }
                .foregroundStyle(isCalibrated ? AppColor.primaryGreen : AppColor.warningForeground)
                .padding(.horizontal, 14)
                .frame(height: 40)
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
}

#Preview {
    VStack(spacing: 16) {
        HomeHeaderView(isCalibrated: false, onCalibrate: {})
        HomeHeaderView(isCalibrated: true, onCalibrate: {})
    }
    .padding()
    .background(AppColor.backgroundGradient)
}
