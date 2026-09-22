//
//  DecayCurveChart.swift
//  HEMOnitor
//

import SwiftUI

/// The chart used by the "curve" visualization style: a forward decay
/// projection with dashed reference lines at 40% and 15% display, a filled
/// area under the curve, and a marker dot at "now" (the first sample).
///
/// Hand-rolled with `Path`/`GeometryReader` rather than Swift Charts, so the
/// exact reference-line and marker treatment from the design mock is fully
/// under our control.
struct DecayCurveChart: View {
    let points: [DecayCurvePoint]
    let color: Color

    /// Fixed reference levels from the design spec — not tied to `SafetyZone`.
    private let referenceLevels: [Double] = [40, 15]

    var body: some View {
        GeometryReader { geo in
            let maxHours = points.last?.hoursFromNow ?? 1
            let maxPercent = max(100, (points.map(\.displayPercent).max() ?? 100) * 1.05)
            let width = geo.size.width
            let height = geo.size.height

            ZStack {
                ForEach(referenceLevels, id: \.self) { level in
                    Path { path in
                        let yPos = y(for: level, maxPercent: maxPercent, height: height)
                        path.move(to: CGPoint(x: 0, y: yPos))
                        path.addLine(to: CGPoint(x: width, y: yPos))
                    }
                    .stroke(AppColor.inkTertiary, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }

                if !points.isEmpty {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: height))
                        for point in points {
                            let pt = CGPoint(
                                x: x(for: point.hoursFromNow, maxHours: maxHours, width: width),
                                y: y(for: point.displayPercent, maxPercent: maxPercent, height: height)
                            )
                            path.addLine(to: pt)
                        }
                        path.addLine(to: CGPoint(x: width, y: height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.28), color.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    Path { path in
                        for (index, point) in points.enumerated() {
                            let pt = CGPoint(
                                x: x(for: point.hoursFromNow, maxHours: maxHours, width: width),
                                y: y(for: point.displayPercent, maxPercent: maxPercent, height: height)
                            )
                            if index == 0 {
                                path.move(to: pt)
                            } else {
                                path.addLine(to: pt)
                            }
                        }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                    if let first = points.first {
                        Circle()
                            .fill(color)
                            .frame(width: 8, height: 8)
                            .position(
                                x: x(for: first.hoursFromNow, maxHours: maxHours, width: width),
                                y: y(for: first.displayPercent, maxPercent: maxPercent, height: height)
                            )
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func x(for hours: Double, maxHours: Double, width: CGFloat) -> CGFloat {
        guard maxHours > 0 else { return 0 }
        return width * CGFloat(hours / maxHours)
    }

    private func y(for percent: Double, maxPercent: Double, height: CGFloat) -> CGFloat {
        height * (1 - CGFloat(percent / maxPercent))
    }
}

#Preview {
    let model = FactorVIIIModel(weightKg: 65, baselinePercent: 2, halfLifeHours: 19)
    DecayCurveChart(
        points: DecayCurve.sample(model: model, currentRealPercent: 68),
        color: AppColor.zoneWellCovered
    )
    .frame(height: 140)
    .padding()
    .background(AppColor.backgroundGradient)
}
