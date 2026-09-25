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

    /// Everything derived from the injection history, computed once per change to it.
    /// See `TimelineData` for why this is cached rather than recomputed in `body`.
    @State private var data = TimelineData()

    /// Measured width of the chart's visible area, needed to know how far it can slide.
    @State private var chartViewportWidth: CGFloat = 0

    /// Captured on appear so the list's scroll handler can drive the chart.
    @State private var chartScroller: ScrollViewProxy?

    /// Index into `data.days` of the day under the centre of the chart's viewport.
    ///
    /// An index, updated only when it actually changes, rather than the chart's raw
    /// content offset: the offset changes every frame of a drag, and storing it here
    /// re-ran `body` every frame for a marker that only moves once per 64pt column.
    @State private var markedDayIndex: Int?

    /// Whether the opening scroll-to-today has happened. One-shot, so a later
    /// re-measure of the viewport doesn't drag the chart back under the user.
    @State private var hasAnchoredOnToday = false

    /// Bookkeeping for the scroll coupling, deliberately a reference type: it is
    /// written on every scroll callback, and as `@State` value it would invalidate the
    /// view each time — which is exactly the per-frame `body` churn being removed here.
    @State private var coupling = ChartCouplingState()

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
        .onAppear { rebuildData() }
        .onChange(of: viewModel.injections) { _, _ in rebuildData() }
        // Anchoring needs both the data and the viewport width, and they arrive in
        // either order — so each one re-checks whether the other has landed.
        .onChange(of: data.range) { _, _ in anchorOnTodayIfReady() }
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
                TimelineCurveChart(points: data.points, range: data.range, markedDay: markedDay)
                    .overlay(alignment: .leading) { scrollAnchors }
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity)
            .frame(height: chartHeight)
            .onTimelineHorizontalScroll { offset in
                updateMarkedDay(chartScrollOffset: offset)
            }
            .onAppear { chartScroller = scroller }
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
                        .onAppear { measureChartViewport(proxy.size.width) }
                        .onChange(of: proxy.size.width) { _, width in
                            measureChartViewport(width)
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
                    // A dedicated id type, not a bare Int: plain `Int` ids collide with
                    // any other `ForEach(0..<n)` inside the same scroll view, and
                    // `scrollTo` would then have two candidates per index.
                    .id(ChartAnchorID(index: index))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private static let anchorSpacing: CGFloat = 8

    private var anchorCount: Int {
        max(1, Int((chartContentWidth / Self.anchorSpacing).rounded(.up)))
    }

    /// Records the chart's viewport width and, once both it and the data are known,
    /// anchors the chart on today.
    ///
    /// The anchoring can't happen in `onAppear` — the width isn't measured yet at that
    /// point, and centring needs it.
    private func measureChartViewport(_ width: CGFloat) {
        guard width > 0, width != chartViewportWidth else { return }
        chartViewportWidth = width
        anchorOnTodayIfReady()
    }

    /// Centres the chart on today, once. The flag keeps a later re-measure (rotation,
    /// iPad split view) from yanking the chart back to today under the user.
    private func anchorOnTodayIfReady() {
        guard !hasAnchoredOnToday, chartViewportWidth > 0, data.range.dayCount > 0 else { return }
        hasAnchoredOnToday = true

        let offset = offsetCentringToday(viewportWidth: chartViewportWidth)
        scrollChart(to: offset)
        // Seed the marker here rather than waiting for a scroll callback: the callback
        // is iOS 18-only, and even there the chart opens without having been dragged.
        updateMarkedDay(chartScrollOffset: offset)
    }

    /// Scrolls the chart so `offset` points of content sit to the left of the viewport.
    ///
    /// Anchors are `anchorSpacing` apart, so consecutive scroll callbacks frequently
    /// resolve to the same one. Skipping those is the point: each `scrollTo` forces a
    /// layout pass over the chart, and firing one per frame for a target that hasn't
    /// moved is what the coupling used to do.
    private func scrollChart(to offset: CGFloat) {
        guard let chartScroller else { return }
        let clamped = min(max(offset, 0), max(0, chartContentWidth - chartViewportWidth))
        let index = min(anchorCount - 1, Int((clamped / Self.anchorSpacing).rounded()))

        guard index != coupling.lastAnchorIndex else { return }
        coupling.lastAnchorIndex = index
        chartScroller.scrollTo(ChartAnchorID(index: index), anchor: .leading)
    }

    /// Total width of the chart's content: one fixed-width column per day.
    private var chartContentWidth: CGFloat {
        CGFloat(data.range.dayCount) * TimelineCurve.dayWidth
    }

    /// Scroll offset that puts today's column under the centre of the viewport — and
    /// therefore under the marker.
    ///
    /// Takes the width as an argument rather than reading `chartViewportWidth`, because
    /// the callers compute it immediately after assigning that state and cannot rely on
    /// the write being visible yet.
    private func offsetCentringToday(viewportWidth: CGFloat) -> CGFloat {
        let calendar = Calendar.current
        let days = data.days
        let todayIndex = days.firstIndex { calendar.isDateInToday($0) } ?? max(0, days.count - 1)
        let columnCentre = CGFloat(todayIndex) * TimelineCurve.dayWidth + TimelineCurve.dayWidth / 2
        return max(0, columnCentre - viewportWidth / 2)
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
                    ForEach(data.groups, id: \.day) { group in
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
        // The list's first scroll report can arrive before the chart's width has been
        // measured. Acting on it then centres the chart half a viewport too far right
        // — three whole day columns on an iPhone — so wait for a real width.
        guard chartViewportWidth > 0, data.range.dayCount > 0 else { return }

        let offset = TimelineCurve.chartScrollOffset(
            scrollOffset: metrics.offset,
            contentHeight: metrics.contentHeight,
            viewportHeight: metrics.viewportHeight,
            // The list holds only past injections, so the top of it means *today*, not
            // the far end of the chart — the projected days past today are reachable
            // by scrolling the chart itself.
            maxChartScroll: offsetCentringToday(viewportWidth: chartViewportWidth)
        )

        // Driven straight from the callback rather than through an intermediate
        // `@State` offset. The state round-trip re-ran `body` on every scroll frame,
        // and `scrollChart` already drops the calls that change nothing.
        scrollChart(to: offset)
    }

    /// Moves the centred-day marker to whichever column now sits under the middle of
    /// the chart's viewport, writing state only when the column actually changes.
    private func updateMarkedDay(chartScrollOffset: CGFloat) {
        guard !data.days.isEmpty, chartViewportWidth > 0 else { return }
        let index = TimelineCurve.centredDayIndex(
            scrollOffset: chartScrollOffset,
            viewportWidth: chartViewportWidth,
            dayCount: data.days.count
        )
        if index != markedDayIndex { markedDayIndex = index }
    }

    // MARK: - Derived data

    /// The day under the centre of the chart's viewport.
    private var markedDay: Date? {
        guard let markedDayIndex, data.days.indices.contains(markedDayIndex) else { return nil }
        return data.days[markedDayIndex]
    }

    /// Recomputes everything derived from the injection history.
    ///
    /// Called when that history changes, and nowhere else — in particular never from
    /// `body`. The range runs from the oldest injection through today *plus* however
    /// many days it takes the level to decay back to baseline, so the chart shows how
    /// much cover is left rather than stopping dead at the present.
    private func rebuildData() {
        let calendar = Calendar.current
        let injections = viewModel.injections

        let range = TimelineCurve.range(
            injections: injections,
            futureDays: TimelineCurve.projectedFutureDays(
                model: viewModel.model,
                currentRealPercent: viewModel.currentRealLevelPercent
            )
        )

        // Injections bucketed by calendar day, newest day first and newest-first
        // within each day.
        let buckets = Dictionary(grouping: injections) { calendar.startOfDay(for: $0.date) }
        let groups = buckets.keys.sorted(by: >).map { day in
            DayGroup(
                day: day,
                title: day.formatted(.dateTime.day().month(.wide).year()),
                injections: buckets[day, default: []].sorted { $0.date > $1.date }
            )
        }

        data = TimelineData(
            range: range,
            days: range.days(calendar: calendar),
            points: TimelineCurve.sample(
                injections: injections,
                model: viewModel.model,
                range: range
            ),
            groups: groups,
            injectionCount: injections.count
        )
    }

    private var chartAccessibilityLabel: String {
        let count = data.injectionCount
        let doses = count == 1 ? "1 injection" : "\(count) injections"
        return "Estimated factor level across \(data.range.dayCount) days, \(doses) logged."
    }
}

/// Injections for one calendar day, with the heading the list shows above them.
private struct DayGroup {
    let day: Date
    let title: String
    let injections: [InjectionEvent]
}

/// Everything the Timeline draws that depends on the injection history rather than on
/// scroll position.
///
/// Cached in `@State` instead of being recomputed as computed properties of the view,
/// which is what made the screen stutter: `body` re-runs on every scroll callback, and
/// each run re-sampled the curve (240 points, each scanning the history), re-grouped
/// and re-sorted the whole list, and re-derived every day column. None of that depends
/// on where the user has scrolled to.
private struct TimelineData {
    var range = TimelineRange(start: .distantPast, dayCount: 0)
    var days: [Date] = []
    var points: [TimelineCurvePoint] = []
    var groups: [DayGroup] = []
    var injectionCount = 0
}

/// Mutable bookkeeping for the chart/list coupling. A class so the scroll handlers can
/// update it without invalidating the view — see `TimelineView.coupling`.
private final class ChartCouplingState {
    /// The anchor the chart was last scrolled to, or -1 before the first scroll.
    var lastAnchorIndex = -1
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

/// Identifies the chart's invisible scroll anchors. A distinct type so these can never
/// be confused with any other identified view inside the same scroll view.
private struct ChartAnchorID: Hashable {
    let index: Int
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

    /// Reports a horizontal scroll view's content offset as it scrolls.
    ///
    /// Used to keep the centred-day marker in step when the chart is dragged by hand.
    /// There is no pre-iOS-18 fallback: on older systems the marker simply follows the
    /// list rather than the chart's own drag, which degrades one detail instead of
    /// pulling a second unreliable geometry-preference path into the view.
    @ViewBuilder
    func onTimelineHorizontalScroll(_ action: @escaping (CGFloat) -> Void) -> some View {
        if #available(iOS 18.0, *) {
            self.onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.x
            } action: { _, offset in
                action(offset)
            }
        } else {
            self
        }
    }
}
