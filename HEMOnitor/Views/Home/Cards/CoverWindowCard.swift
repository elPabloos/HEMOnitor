//
//  CoverWindowCard.swift
//  HEMOnitor
//

import SwiftUI

/// The "cover window" card: a headline projecting when the level crosses a
/// fixed reference threshold, plus the "look ahead" slider (0...72h, forward only).
///
/// **The slider does not belong to this card.** It drives the whole Home screen:
/// `HomeView` owns the offset, projects the level once, and hands the result to the
/// ring/numeral/curve, the zone badge and this card alike — so dragging it moves the
/// big number, not just a line of text down here. This card only renders the control
/// and reports the instant being previewed.
///
/// All math stays in real space until the final `displayLevel`/`realPercent`
/// conversion, matching CLAUDE.md's real vs. display split. The projection itself is
/// `DecayCurve.projectedRealPercent`, a pure function over
/// `FactorVIIIModel.levelAtTime` — forward-only, so the backwards-decay branch the
/// old `HomeView.simulatedDisplayInfo()` hand-rolled is still not needed.
struct CoverWindowCard: View {
    let model: FactorVIIIModel

    /// The real level **at `asOf`**, already projected by the caller. The whole Home
    /// screen renders as of that instant, so this card must not project again.
    let currentRealPercent: Double

    /// The instant the card is reporting on: now, or now + the look-ahead offset.
    let asOf: Date

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

    private var isPreviewing: Bool { lookAheadHours > 0 }

    /// "Now" or "+12h", mirroring the mock's badge beside the slider.
    private var lookAheadLabel: String {
        isPreviewing ? "+\(Int(lookAheadHours))h" : "Now"
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
                HStack {
                    Text("Look ahead")
                        .font(AppTextStyle.caption)
                        .foregroundStyle(AppColor.inkSecondary)
                    Spacer()
                    Text(lookAheadLabel)
                        .font(AppTextStyle.monoValue)
                        .foregroundStyle(AppColor.primaryGreen)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.12), value: lookAheadHours)
                }

                Slider(value: $lookAheadHours, in: 0...72, step: 1)
                    .tint(AppColor.primaryGreen)
                    .accessibilityLabel("Look ahead")
                    .accessibilityValue(isPreviewing ? "\(Int(lookAheadHours)) hours ahead" : "Now")

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

                if isPreviewing {
                    // The level shown above the card is already the projected one, so
                    // this names the moment rather than repeating the number.
                    Text("Previewing \(asOf.formatted(date: .abbreviated, time: .shortened))")
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
                // Counted from the instant being previewed, so the headline stays
                // consistent with the level shown above it.
                let crossDate = asOf.addingTimeInterval(hoursUntilThreshold * 3600)
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
        CoverWindowCard(model: model, currentRealPercent: 40, asOf: Date(), lookAheadHours: .constant(0))
        CoverWindowCard(
            model: model,
            currentRealPercent: 14,
            asOf: Date().addingTimeInterval(24 * 3600),
            lookAheadHours: .constant(24)
        )
    }
    .padding()
    .background(AppColor.backgroundGradient)
}
