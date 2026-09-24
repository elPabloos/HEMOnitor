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

    /// Where the list's scroll position says the chart should sit: points of content
    /// scrolled past the leading edge. Driving a value rather than calling `scrollTo`
    /// directly from the scroll handler keeps the coupling declarative and lets the
    /// mapping stay a tested pure function.
    @State private var targetChartOffset: CGFloat = 0

    /// Measured width of the chart's visible area, needed to know how far it can slide.
    @State private var chartViewportWidth: CGFloat = 0

    /// Captured on appear so the list's scroll handler can drive the chart.
    @State private var chartScroller: ScrollViewProxy?

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

    /// The chart is far wider than the screen (64pt × one column per day) and lives in
    /// a real horizontal `ScrollView`, so it can be dragged directly *and* driven
    /// programmatically from the list below. A `ScrollView` also solves the width
    /// problem for free: it accepts the proposed width and scrolls its content, rather
    /// than forcing the whole screen as wide as the chart.
    private var chart: some View {
        ScrollViewReader { scroller in
            ScrollView(.horizontal) {
                TimelineCurveChart(points: points, range: range)
                    .overlay(alignment: .leading) { scrollAnchors }
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity)
            .frame(height: chartHeight)
            .onAppear {
                chartScroller = scroller
                scrollChart(to: chartContentWidth, animated: false)
            }
            .onChange(of: targetChartOffset) { _, offset in
                scrollChart(to: offset, animated: false)
            }
        }
            .overlay(alignment: .topLeading) {
                // Behind the data, spanning the viewport — see TimelineChartGuides.
                TimelineChartGuides()
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
                        .onAppear { chartViewportWidth = proxy.size.width }
                        .onChange(of: proxy.size.width) { _, width in
                            chartViewportWidth = width
                        }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(chartAccessibilityLabel)
    }

    /// Invisible, evenly spaced scroll targets laid across the chart's width.
    ///
    /// `ScrollViewReader` can only scroll *to a view*, so positioning the chart at an
    /// arbitrary x means having a view at that x to aim at. One target per day would
    /// snap in 64pt jumps — visibly stepped, and not the continuous pan the mock
    /// specifies. Anchors every `anchorSpacing` points make `scrollTo` fine-grained
    /// enough to read as smooth, on every supported iOS version, while the chart stays
    /// a real `ScrollView` (native momentum, rubber-banding, and VoiceOver scrolling).
    private var scrollAnchors: some View {
        HStack(spacing: 0) {
            ForEach(0..<anchorCount, id: \.self) { index in
                Color.clear
                    .frame(width: Self.anchorSpacing, height: 1)
                    .id(index)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private static let anchorSpacing: CGFloat = 8

    private var anchorCount: Int {
        max(1, Int((chartContentWidth / Self.anchorSpacing).rounded(.up)))
    }

    /// Scrolls the chart so `offset` points of content sit to the left of the viewport.
    private func scrollChart(to offset: CGFloat, animated: Bool) {
        guard let chartScroller else { return }
        let clamped = min(max(offset, 0), max(0, chartContentWidth - chartViewportWidth))
        let index = min(anchorCount - 1, Int((clamped / Self.anchorSpacing).rounded()))

        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                chartScroller.scrollTo(index, anchor: .leading)
            }
        } else {
            chartScroller.scrollTo(index, anchor: .leading)
        }
    }

    /// Total width of the chart's content: one fixed-width column per day.
    private var chartContentWidth: CGFloat {
        CGFloat(range.dayCount) * TimelineCurve.dayWidth
    }

    /// The outer `GeometryReader` measures the list's viewport. That measurement is
    /// what makes the coupling correct: scroll progress is
    /// `offset / (contentHeight - viewportHeight)`, and an earlier version guessed the
    /// viewport at a fixed 320pt, which collapsed the denominator on short histories
    /// and left the chart barely moving.
    private var list: some View {
        GeometryReader { viewport in
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
                    // Reports how far the list has scrolled, which picks the day the
                    // chart scrolls to: list at top = today, list at bottom = oldest.
                    GeometryReader { content in
                        Color.clear.preference(
                            key: TimelineScrollOffsetKey.self,
                            value: TimelineScrollMetrics(
                                offset: -content.frame(in: .named(Self.scrollSpace)).minY,
                                contentHeight: content.size.height,
                                viewportHeight: viewport.size.height
                            )
                        )
                    }
                }
            }
            .coordinateSpace(name: Self.scrollSpace)
            .scrollIndicators(.hidden)
            .onTimelineScroll { metrics in
                syncChart(to: metrics)
            }
        }
    }

    // MARK: - Scroll coupling

    private static let scrollSpace = "timelineList"

    /// Picks the day the chart should centre on from how far the list has scrolled.
    ///
    /// The list runs newest-first, so scrolling *down* walks *back* in time — hence
    /// the inversion. Mapping to a day rather than to a raw pixel offset means the
    /// chart lands on whole columns and stays meaningful: the curve you are looking at
    /// belongs to the entries you are reading.
    private func syncChart(to metrics: TimelineScrollMetrics) {
        targetChartOffset = TimelineCurve.chartScrollOffset(
            scrollOffset: metrics.offset,
            contentHeight: metrics.contentHeight,
            viewportHeight: metrics.viewportHeight,
            maxChartScroll: max(0, chartContentWidth - chartViewportWidth)
        )
    }

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
///
/// `viewportHeight` is measured rather than assumed — it is the denominator of the
/// scroll-progress calculation, and guessing it at a constant 320pt is what broke the
/// coupling in the first implementation.
struct TimelineScrollMetrics: Equatable {
    var offset: CGFloat = 0
    var contentHeight: CGFloat = 0
    var viewportHeight: CGFloat = 0
}

private struct TimelineScrollOffsetKey: PreferenceKey {
    static var defaultValue = TimelineScrollMetrics()
    static func reduce(value: inout TimelineScrollMetrics, nextValue: () -> TimelineScrollMetrics) {
        value = nextValue()
    }
}

extension View {
    /// Reports a scroll view's position, size and viewport as it scrolls.
    ///
    /// Two implementations. On iOS 18 and later this is `onScrollGeometryChange`, the
    /// API built for exactly this and the one that reliably fires *during* a drag. The
    /// geometry-preference fallback below it is what the first implementation used
    /// everywhere, and it never fired in practice — so it is kept only to satisfy the
    /// project's iOS 17.5 floor, not because it is trusted.
    ///
    /// The caller must still apply `.coordinateSpace(name:)` and place the matching
    /// `timelineScrollMetricsReader()` background for the fallback path to work.
    @ViewBuilder
    func onTimelineScroll(_ action: @escaping (TimelineScrollMetrics) -> Void) -> some View {
        if #available(iOS 18.0, *) {
            self.onScrollGeometryChange(for: TimelineScrollMetrics.self) { geometry in
                TimelineScrollMetrics(
                    offset: geometry.contentOffset.y,
                    contentHeight: geometry.contentSize.height,
                    viewportHeight: geometry.containerSize.height
                )
            } action: { _, metrics in
                action(metrics)
            }
        } else {
            self.onPreferenceChange(TimelineScrollOffsetKey.self) { metrics in
                action(metrics)
            }
        }
    }
}
