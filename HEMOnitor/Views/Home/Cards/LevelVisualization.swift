//
//  LevelVisualization.swift
//  HEMOnitor
//

import SwiftUI

/// The main level visualization: one of three user-selectable styles
/// (`DisplayStyle.ring` / `.numeral` / `.curve`), all reading a single
/// DISPLAY-space percentage (never computed here — always handed in already
/// converted via `FactorVIIIModel.displayLevel(fromRealPercent:)`).
///
/// The style switcher is a compact three-way control below the visualization;
/// picking a style calls `onStyleChange`, which the caller wires to
/// `viewModel.displayStyle` — persisted automatically by the view model.
struct LevelVisualization: View {
    let displayPercent: Double
    let zone: SafetyZone
    let style: DisplayStyle
    let curvePoints: [DecayCurvePoint]
    let onStyleChange: (DisplayStyle) -> Void

    /// Whether the value is currently being scrubbed by the look-ahead slider.
    ///
    /// While scrubbing, the level must track the finger exactly — so the transition
    /// is dropped entirely. An eased animation here reads as lag: the slider emits a
    /// change per step, each restarting a transition that the next one interrupts, so
    /// the number is permanently chasing a value the finger has already passed.
    var isScrubbing: Bool = false

    /// Smooth for the reasons a level changes on its own — the 60-second refresh, a
    /// newly logged dose, a calibration — and absent while scrubbing.
    private var valueAnimation: Animation? {
        isScrubbing ? nil : .easeInOut(duration: 0.35)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.stackGapLarge) {
            Group {
                switch style {
                case .ring:
                    ringBody
                case .numeral:
                    numeralBody
                case .curve:
                    curveBody
                }
            }
            .animation(valueAnimation, value: displayPercent)

            styleSwitcher
        }
    }

    private var caption: some View {
        Text("estimated plasma factor")
            .font(AppTextStyle.caption)
            .foregroundStyle(AppColor.inkSecondary)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
    }

    private func numeralText(_ size: CGFloat, percentSize: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(displayPercent.wholeNumberText)
                .font(.jakarta(size, weight: .extraBold))
            Text("%")
                .font(.jakarta(percentSize, weight: .extraBold))
        }
        .foregroundStyle(AppColor.ink)
        .lineLimit(1)
        // The numeral is already 82–132pt; at accessibility sizes it bursts straight
        // out of the ring. Shrinking to fit keeps the reading legible and the
        // geometry intact.
        .minimumScaleFactor(0.5)
    }

    private var ringBody: some View {
        ZStack {
            Circle()
                .stroke(AppColor.ink.opacity(0.08), lineWidth: 14)
            Circle()
                .trim(from: 0, to: min(1, max(0, displayPercent / 100)))
                .stroke(zone.color, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 4) {
                numeralText(82, percentSize: 28)
                caption
            }
            .padding(.horizontal, 28)
            // The ring is a fixed 250pt circle, so its contents cannot scale without
            // bound. Capping below the accessibility sizes (they still get the full
            // XXXL step) keeps the number inside the circle; VoiceOver users get the
            // combined label above, which is unaffected by this cap.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
        .frame(width: 250, height: 250)
        .accessibilityElement(children: .combine)
    }

    private var numeralBody: some View {
        VStack(spacing: 6) {
            numeralText(132, percentSize: 40)
            caption
        }
        .padding(.horizontal, Theme.Spacing.screenGutter)
        // 132pt is already near the screen width; the accessibility steps would take
        // it well past it, and `minimumScaleFactor` alone would shrink it back to
        // roughly this size anyway.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .frame(minHeight: 250)
        .accessibilityElement(children: .combine)
    }

    private var curveBody: some View {
        VStack(spacing: 10) {
            numeralText(84, percentSize: 24)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            caption

            DecayCurveChart(points: curvePoints, color: zone.color)
                .frame(height: 140)

            HStack {
                Text("now")
                Spacer()
                Text("+2 days")
                Spacer()
                Text("+4 days")
            }
            .font(AppTextStyle.monoLabel)
            .foregroundStyle(AppColor.inkTertiary)
        }
        .frame(minHeight: 250)
        .accessibilityElement(children: .combine)
    }

    private var styleSwitcher: some View {
        HStack(spacing: 6) {
            styleButton(.ring, icon: "circle.dashed", label: "Ring")
            styleButton(.numeral, icon: "textformat.123", label: "Numeral")
            styleButton(.curve, icon: "chart.xyaxis.line", label: "Curve")
        }
        .padding(4)
        .background {
            Capsule().fill(AppColor.ink.opacity(0.05))
        }
        .accessibilityElement(children: .contain)
    }

    private func styleButton(_ target: DisplayStyle, icon: String, label: String) -> some View {
        let isSelected = target == style
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { onStyleChange(target) }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 40, height: 32)
                .foregroundStyle(isSelected ? Color.white : AppColor.inkSecondary)
                .background {
                    Capsule().fill(isSelected ? AppColor.primaryGreen : .clear)
                }
                // The pill stays 40x32 for the design; the *tappable* area is padded
                // out to the 44pt minimum, which the visual alone did not meet.
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) style")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    let model = FactorVIIIModel(weightKg: 65, baselinePercent: 2, halfLifeHours: 19)
    let percent = 68.0
    return VStack(spacing: 24) {
        LevelVisualization(
            displayPercent: percent,
            zone: SafetyZone(displayPercent: percent),
            style: .ring,
            curvePoints: DecayCurve.sample(model: model, currentRealPercent: percent),
            onStyleChange: { _ in }
        )
        LevelVisualization(
            displayPercent: percent,
            zone: SafetyZone(displayPercent: percent),
            style: .curve,
            curvePoints: DecayCurve.sample(model: model, currentRealPercent: percent),
            onStyleChange: { _ in }
        )
    }
    .padding()
    .background(AppColor.backgroundGradient)
}
