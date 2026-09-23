//
//  TimelineView.swift
//  HEMOnitor
//

import SwiftUI

/// Full-screen history: the estimated FVIII curve across every day with a logged
/// injection, above a day-grouped list of those injections.
///
/// The chart is pinned at the top while the list scrolls under it, and the two axes
/// are coupled — scrolling the list back through older entries pans the chart back
/// over the same period. See `TimelineCurve` for the sampling and geometry, which are
/// pure and unit-tested.
struct TimelineView: View {
    @ObservedObject var viewModel: FactorTrackerViewModel
    let onClose: () -> Void

    @State private var editing: InjectionEvent?
    /// Horizontal offset of the chart, driven by the list's vertical offset.
    @State private var chartOffset: CGFloat = 0
    /// Width available to the chart viewport, needed to clamp `chartOffset`.
    @State private var viewportWidth: CGFloat = 0

    private let chartHeight: CGFloat = 360

    var body: some View {
        VStack(spacing: 0) {
            header

            Rectangle()
                .fill(AppColor.ink.opacity(0.55))
                .frame(height: 1.5)

            if viewModel.injections.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .background(AppColor.backgroundGradient.ignoresSafeArea())
        .sheet(item: $editing) { injection in
            EditInjectionSheet(
                viewModel: viewModel,
                injection: injection,
                onClose: { editing = nil }
            )
        }
    }

    // MARK: - Chrome

    private var header: some View {
        ZStack {
            Text("Timeline")
                .font(AppTextStyle.headline)
                .foregroundStyle(AppColor.ink)

            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColor.inkSecondary)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(AppColor.ink.opacity(0.07)))
                }
                .accessibilityLabel("Close timeline")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.Spacing.screenGutter)
        .padding(.top, Theme.Spacing.stackGapLarge)
        .padding(.bottom, Theme.Spacing.stackGap)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.stackGap) {
            Spacer()
            Text("Nothing logged yet")
                .font(AppTextStyle.headline)
                .foregroundStyle(AppColor.ink)
            Text("Once you log a dose, your estimated level over time appears here.")
                .font(AppTextStyle.body)
                .foregroundStyle(AppColor.inkSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.screenGutter)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: 0) {
            chart
            list
        }
    }

    /// The chart is far wider than the screen (64pt × one column per day), so it is
    /// hung in an `overlay` on a flexible spacer rather than placed as a normal child.
    /// A child that wide would otherwise set the width for this whole screen, pushing
    /// the header button, the scale labels and every list row off to the left.
    private var chart: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: chartHeight)
            .overlay(alignment: .topLeading) {
                // Scrolls horizontally, but driven by the list's offset below rather
                // than by dragging, so the two axes stay in step.
                TimelineCurveChart(points: points, range: range)
                    .offset(x: chartOffset)
            }
            .overlay(alignment: .topLeading) {
                Text("FVIII activity (% of normal)")
                    .font(.jakarta(10.5, weight: .bold))
                    .tracking(0.9)
                    .textCase(.uppercase)
                    .foregroundStyle(AppColor.ink.opacity(0.72))
                    .padding(.leading, 14)
                    .padding(.top, 8)
            }
            .overlay(alignment: .topLeading) {
                TimelineScaleLabels()
                    .padding(.leading, 14)
            }
            .clipped()
            .background(AppColor.glassFillStrong)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(AppColor.ink.opacity(0.09))
                    .frame(height: 1)
            }
            .themeShadow(.ambientCard)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { setViewportWidth(proxy.size.width) }
                        .onChange(of: proxy.size.width) { _, width in setViewportWidth(width) }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(chartAccessibilityLabel)
    }

    /// Re-anchors the chart to today whenever the viewport is (re)measured — the
    /// scrollable distance isn't known until then.
    private func setViewportWidth(_ width: CGFloat) {
        guard width != viewportWidth else { return }
        viewportWidth = width
        chartOffset = -maxChartScroll
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(groups, id: \.day) { group in
                    Text(group.title)
                        .font(.jakarta(13, weight: .extraBold))
                        .foregroundStyle(AppColor.ink)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                        .padding(.horizontal, 2)

                    ForEach(group.injections) { injection in
                        TimelineInjectionRow(
                            injection: injection,
                            fallbackProductName: viewModel.productName,
                            onTap: { editing = injection }
                        )
                        .padding(.bottom, 9)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 26)
            .background {
                // Reports how far the list has scrolled, which drives the chart's
                // horizontal offset: list at top = chart at today.
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: TimelineScrollOffsetKey.self,
                        value: TimelineScrollMetrics(
                            offset: -proxy.frame(in: .named(Self.scrollSpace)).minY,
                            contentHeight: proxy.size.height
                        )
                    )
                }
            }
        }
        .coordinateSpace(name: Self.scrollSpace)
        .scrollIndicators(.hidden)
        .onPreferenceChange(TimelineScrollOffsetKey.self) { metrics in
            syncChart(to: metrics)
        }
    }

    // MARK: - Scroll coupling

    private static let scrollSpace = "timelineList"

    /// How far the chart can slide before its right edge (today) is flush.
    private var maxChartScroll: CGFloat {
        max(0, CGFloat(range.dayCount) * TimelineCurve.dayWidth - viewportWidth)
    }

    /// Maps the list's scroll progress onto the chart's horizontal offset. The list
    /// runs newest-first, so scrolling *down* walks *back* in time — hence the
    /// inversion.
    private func syncChart(to metrics: TimelineScrollMetrics) {
        guard maxChartScroll > 0, metrics.contentHeight > 0 else {
            chartOffset = 0
            return
        }
        let scrollable = max(1, metrics.contentHeight - viewportHeightEstimate)
        let progress = min(max(metrics.offset / scrollable, 0), 1)
        chartOffset = -(1 - progress) * maxChartScroll
    }

    /// The list viewport isn't measured directly; its height is whatever is left below
    /// the chart. An approximation is fine — it only affects how quickly the chart
    /// pans, not where it starts or ends.
    private var viewportHeightEstimate: CGFloat { 320 }

    // MARK: - Derived data

    private var range: TimelineRange {
        TimelineCurve.range(injections: viewModel.injections)
    }

    private var points: [TimelineCurvePoint] {
        TimelineCurve.sample(
            injections: viewModel.injections,
            model: viewModel.model,
            range: range
        )
    }

    private struct DayGroup {
        let day: Date
        let title: String
        let injections: [InjectionEvent]
    }

    /// Injections bucketed by calendar day, newest day first and newest-first within
    /// each day.
    private var groups: [DayGroup] {
        let calendar = Calendar.current
        let buckets = Dictionary(grouping: viewModel.injections) { calendar.startOfDay(for: $0.date) }
        return buckets.keys.sorted(by: >).map { day in
            DayGroup(
                day: day,
                title: day.formatted(.dateTime.day().month(.wide).year()),
                injections: buckets[day, default: []].sorted { $0.date > $1.date }
            )
        }
    }

    private var chartAccessibilityLabel: String {
        let count = viewModel.injections.count
        let doses = count == 1 ? "1 injection" : "\(count) injections"
        return "Estimated factor level across \(range.dayCount) days, \(doses) logged."
    }
}

/// Carries the list's scroll position up to the chart.
private struct TimelineScrollMetrics: Equatable {
    var offset: CGFloat = 0
    var contentHeight: CGFloat = 0
}

private struct TimelineScrollOffsetKey: PreferenceKey {
    static var defaultValue = TimelineScrollMetrics()
    static func reduce(value: inout TimelineScrollMetrics, nextValue: () -> TimelineScrollMetrics) {
        value = nextValue()
    }
}
