//
//  CalibrationCTACard.swift
//  HEMOnitor
//

import SwiftUI

/// The prominent green calibration call-to-action. `YouView` doesn't build the
/// calibration flow itself — `onTap` hands off to whatever presents `CalibrationView`.
struct CalibrationCTACard: View {
    /// Whether `FactorVIIIModel.calibrationFactor` is currently set.
    let isCalibrated: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Theme.Spacing.stackGapSmall) {
                Text("Calibrate with a lab result")
                    .font(AppTextStyle.headline)
                    .foregroundStyle(.white)

                Text("One measured FVIII value scales the curve to better match your real recovery.")
                    .font(AppTextStyle.body)
                    .foregroundStyle(.white.opacity(0.85))

                HStack {
                    Text(isCalibrated ? "Calibration active" : "Not calibrated yet")
                        .font(AppTextStyle.caption)
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(Theme.Spacing.cardPadding)
        .background(AppColor.brandGradient, in: RoundedRectangle(cornerRadius: Theme.Radius.cardLarge, style: .continuous))
        .themeShadow(.ctaGreen)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Calibrate with a lab result, \(isCalibrated ? "calibration active" : "not calibrated yet")")
        .accessibilityHint("Opens the calibration flow")
    }
}

#Preview {
    VStack(spacing: 16) {
        CalibrationCTACard(isCalibrated: false, onTap: {})
        CalibrationCTACard(isCalibrated: true, onTap: {})
    }
    .padding()
    .background(AppColor.backgroundGradient)
}
