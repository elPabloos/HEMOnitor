//
//  CoverWindowCard.swift
//  HEMOnitor
//

import SwiftUI

/// The "cover window" card: a headline projecting when the level crosses a
/// fixed reference threshold, plus a "look ahead" slider (0...72h, forward
/// only) that previews a later point on the same decay curve.
///
/// All math stays in real space until the final `displayLevel`/`realPercent`
/// conversion, matching CLAUDE.md's real vs. display split. The look-ahead
/// preview reuses `FactorVIIIModel.levelAtTime` directly — the old
/// `HomeView.simulatedDisplayInfo()` hand-rolled a *backwards* decay branch
/// because it supported negative offsets; since this slider is forward-only
/// (0...72h), that branch isn't needed here.
struct CoverWindowCard: View {
    let model: FactorVIIIModel
    let currentRealPercent: Double
    @Binding var lookAheadHours: Double

    /// Fixed reference level: the boundary between "moderate" and "severe"
    /// coverage (see `SafetyZone`). Not user-configurable in this design —
    /// this supersedes the old free-text threshold field on `NextDoseCard`.
    private let referenceDisplayPercent: Double = 5

    private var hoursUntilThreshold: Double? {
        let referenceReal = model.realPercent(fromDisplayPercent: referenceDisplayPercent)
        return model.hoursUntilLevelReaches(
            targetRealPercent: referenceReal,
            fromRealPercent: currentRealPercent
        )
    }

    private var previewDate: Date? {
        guard lookAheadHours > 0 else { return nil }
        return Date().addingTimeInterval(lookAheadHours * 3600)
    }

    private var previewDisplayPercent: Double? {
        guard lookAheadHours > 0 else { return nil }
        let real = model.levelAtTime(peakPercent: currentRealPercent, hoursSincePeak: lookAheadHours)
        return model.displayLevel(fromRealPercent: real)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.stackGap) {
            HStack {
                Text("Cover window")
                    .font(AppTextStyle.headline)
                    .foregroundStyle(AppColor.ink)
                Spacer()
                Text("\(Int(model.halfLifeHours))h half-life")
                    .font(AppTextStyle.monoLabel)
                    .foregroundStyle(AppColor.inkSecondary)
            }

            headline

            VStack(alignment: .leading, spacing: 8) {
                Text("Look ahead")
                    .font(AppTextStyle.caption)
                    .foregroundStyle(AppColor.inkSecondary)

                Slider(value: $lookAheadHours, in: 0...72, step: 1)
                    .tint(AppColor.primaryGreen)

                HStack {
                    Text("Now")
                    Spacer()
                    Text("+24h")
                    Spacer()
                    Text("+48h")
                    Spacer()
                    Text("+72h")
                }
                .font(AppTextStyle.monoLabel)
                .foregroundStyle(AppColor.inkTertiary)

                if let previewDate, let previewDisplayPercent {
                    Text("Previewing \(previewDate.formatted(date: .abbreviated, time: .shortened)) · \(Int(previewDisplayPercent.rounded()))%")
                        .font(AppTextStyle.caption)
                        .foregroundStyle(AppColor.primaryGreen)
                }
            }
        }
        .glassCard()
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let hoursUntilThreshold {
                let crossDate = Date().addingTimeInterval(hoursUntilThreshold * 3600)
                Text("Below \(Int(referenceDisplayPercent))% around \(crossDate.formatted(date: .abbreviated, time: .shortened))")
                    .font(AppTextStyle.headline)
                    .foregroundStyle(AppColor.ink)
                Text(relativeDurationText(hoursUntilThreshold))
                    .font(AppTextStyle.monoValue)
                    .foregroundStyle(AppColor.inkSecondary)
            } else {
                Text(currentRealPercent > model.baselinePercent ? "Holding above the reference level" : "At baseline")
                    .font(AppTextStyle.headline)
                    .foregroundStyle(AppColor.ink)
            }
        }
    }

    private func relativeDurationText(_ hours: Double) -> String {
        if hours < 1 {
            return "in \(Int((hours * 60).rounded()))min"
        } else if hours < 48 {
            return "in " + String(format: "%.1fh", hours)
        } else {
            return "in " + String(format: "%.1fd", hours / 24)
        }
    }
}

#Preview {
    let model = FactorVIIIModel(weightKg: 65, baselinePercent: 2, halfLifeHours: 19)
    return VStack {
        CoverWindowCard(model: model, currentRealPercent: 40, lookAheadHours: .constant(0))
        CoverWindowCard(model: model, currentRealPercent: 40, lookAheadHours: .constant(24))
    }
    .padding()
    .background(AppColor.backgroundGradient)
}
