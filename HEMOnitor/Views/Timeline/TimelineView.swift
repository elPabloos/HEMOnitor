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

    /// Where the chart should sit horizontally.
    ///
    /// Held in a reference type that only the chart's own scroller observes, so the
    /// sixty-times-a-second traffic of a scroll never reaches this view — which owns
    /// the list and every injection row in it. Deliberately `@State` rather than
    /// `@StateObject`: `@State` keeps the instance alive without subscribing to it.
    @State private var pan = ChartPan()

    /// Index into `data.days` of the day under the centre of the chart's viewport.
    ///
    /// An index, updated only when it actually changes, rather than the chart's raw
    /// content offset: the offset changes every frame of a drag, and storing it here
    /// re-ran `body` every frame for a marker that only moves once per 64pt column.
    @State private var markedDayIndex: Int?

    /// Whether the opening scroll-to-today has happened. One-shot, so a later
    /// re-measure of the viewport doesn't drag the chart back under the user.
    @State private var hasAnchoredOnToday = false

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
        chartScroller
            .frame(maxWidth: .infinity)
            .frame(height: chartHeight)
            .overlay(alignment: .top) { centredDayMarker }
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
            // The chart is fixed geometry — 64pt day columns holding a day number in a
            // 34pt frame — so its labels cannot grow with body text: past this size they
            // truncate to "…" and the scale labels overrun the plot. Bounding the chart
            // keeps it legible and keeps `markerHeight` valid, while everything outside
            // it (the whole injection list) still scales without limit. The chart's
            // content is also available to VoiceOver via `chartAccessibilityLabel`.
            .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }

    /// The scrolling chart itself, in whichever of the two implementations this system
    /// supports. See `CoupledChartScroller` for why they differ.
    @ViewBuilder
    private var chartScroller: some View {
        if #available(iOS 18.0, *) {
            CoupledChartScroller(pan: pan, onOffsetChange: updateMarkedDay) {
                chartContent
            }
        } else {
            LegacyChartScroller(centreOn: data.days.first(where: \.isToday)?.day ?? data.days.last?.day) {
                chartContent
            }
        }
    }

    private var chartContent: some View {
        TimelineCurveChart(
            points: data.points,
            range: data.range,
            days: data.days
        )
        // Top-aligned so the day axis lands at a known y. The content is shorter than
        // `chartHeight`, and a horizontal `ScrollView` centres a short child
        // vertically — which shifted the axis ~10pt below where `centredDayMarker`
        // positions itself, leaving the real column's weekday visible under the pill.
        .frame(maxHeight: .infinity, alignment: .top)
    }

    /// Names the day under the centre of the viewport — and stays put while the axis
    /// slides beneath it.
    ///
    /// Fixed to the viewport rather than drawn on its day's column inside the scrolling
    /// content, which is how the reference behaves: across a slow drag the strip moves
    /// several points per frame while the pill never does. Keeping it out of the
    /// content also keeps `TimelineCurveChart`'s inputs constant during a pan, so its
    /// body — and the whole per-day axis — is skipped entirely.
    ///
    /// Opaque on purpose: the labels it covers are still rendered underneath it.
    @ViewBuilder
    private var centredDayMarker: some View {
        if let label = centredDayLabel {
            // The text is set tighter than the plain columns' number-over-weekday
            // spacing, but the fill around it is sized to cover a whole column
            // (34pt number + 4pt + weekday) with a little to spare. Both parts matter:
            // compact text keeps the weekday clear of the capsule's curved end, while
            // the oversized fill stops the real column's own weekday showing below the
            // pill — which rendered "Fri" twice.
            VStack(spacing: 1) {
                Text(label.dayNumber)
                    .font(.jakarta(13, weight: .extraBold))
                Text(label.weekday)
                    .font(.jakarta(10.5, weight: .bold))
                    .opacity(0.85)
            }
            .foregroundStyle(Color.white)
            .frame(width: 46, height: Self.markerHeight)
            .background(Capsule().fill(AppColor.primaryGreen))
            .padding(.top, TimelineCurve.plotHeight + TimelineCurve.dayAxisTopPadding - Self.markerBleed)
            .allowsHitTesting(false)
            // The chart already carries a summary label; this would only add noise.
            .accessibilityHidden(true)
        }
    }

    /// How far the marker's fill bleeds above and below a day column, so it covers the
    /// column whatever the rendered text metrics turn out to be.
    private static let markerBleed: CGFloat = 3

    /// Tall enough to cover a full day column: 34pt number frame + 4pt spacing +
    /// the weekday line, plus `markerBleed` at each end.
    ///
    /// The first two terms are fixed frames in `dayColumn`; only the weekday line is a
    /// text metric, and it is bounded because the chart caps its Dynamic Type at
    /// `xLarge` (see `chart`). Without that cap this number would be wrong at accessible
    /// sizes and the column's own weekday would reappear below the marker.
    private static let markerHeight: CGFloat = 34 + 4 + 14 + markerBleed * 2

    private var centredDayLabel: TimelineDayLabel? {
        guard let markedDayIndex, data.days.indices.contains(markedDayIndex) else { return nil }
        return data.days[markedDayIndex]
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

        let offset = clampedChartOffset(offsetCentringToday(viewportWidth: chartViewportWidth))
        pan.target = offset
        // Seed the marker here rather than waiting for a scroll callback: the callback
        // is iOS 18-only, and even there the chart opens without having been dragged.
        updateMarkedDay(chartScrollOffset: offset)
    }

    /// Keeps a desired offset inside the range the chart can actually occupy.
    private func clampedChartOffset(_ offset: CGFloat) -> CGFloat {
        min(max(offset, 0), max(0, chartContentWidth - chartViewportWidth))
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
        let days = data.days
        let todayIndex = days.firstIndex(where: \.isToday) ?? max(0, days.count - 1)
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

        // A plain continuous offset. The previous version quantised this to the nearest
        // of a grid of invisible 8pt anchor views, because `ScrollViewReader` can only
        // scroll *to a view* — so between anchors the chart did not move at all and
        // then jumped 8pt, which is the stepping that showed up as a stutter at slow
        // scroll speeds.
        pan.target = clampedChartOffset(offset)
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
            days: TimelineCurve.dayLabels(for: range, calendar: calendar),
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
    var days: [TimelineDayLabel] = []
    var points: [TimelineCurvePoint] = []
    var groups: [DayGroup] = []
    var injectionCount = 0
}

/// Where the chart should sit horizontally, as a plain content offset in points.
///
/// An `ObservableObject` so exactly one view — the chart's scroller — subscribes to
/// it. The list writes to it on every scroll callback; routing that through the
/// enclosing view's `@State` instead would re-run `TimelineView.body`, and with it the
/// whole injection list, sixty times a second.
private final class ChartPan: ObservableObject {
    @Published var target: CGFloat = 0
}

/// The chart's scroller on iOS 18 and later.
///
/// `ScrollPosition.scrollTo(x:)` takes an exact offset, which is the whole point: the
/// previous implementation could only scroll *to a view*, so it carpeted the chart with
/// one invisible anchor view per 8pt and snapped to the nearest. That cost a view per
/// 8pt of a chart that is 64pt per day — over a thousand of them across a few months of
/// history, rebuilt on every marker change — and it quantised the pan into 8pt hops.
@available(iOS 18.0, *)
private struct CoupledChartScroller<Content: View>: View {
    @ObservedObject var pan: ChartPan
    /// Reports the chart's real offset back, so the centred-day marker keeps up with a
    /// hand-drag as well as with the list.
    let onOffsetChange: (CGFloat) -> Void
    @ViewBuilder var content: Content

    @State private var position = ScrollPosition()

    var body: some View {
        ScrollView(.horizontal) {
            content
        }
        .scrollIndicators(.hidden)
        .scrollPosition($position)
        .onChange(of: pan.target) { _, target in
            position.scrollTo(x: target)
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.x
        } action: { _, offset in
            onOffsetChange(offset)
        }
    }
}

/// The chart's scroller before iOS 18, where `ScrollPosition` does not exist.
///
/// Hand-dragging works; the list coupling does not, because the scroll reporting it
/// needs (`onScrollGeometryChange`) is itself iOS 18-only and the geometry-preference
/// fallback it replaced never fired in practice. That is the behaviour this system
/// already had. Opening centred on today still works, via the day ids the axis
/// publishes — day granularity is all an initial position needs.
private struct LegacyChartScroller<Content: View>: View {
    let centreOn: Date?
    @ViewBuilder var content: Content

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                content
            }
            .scrollIndicators(.hidden)
            .onAppear {
                guard let centreOn else { return }
                // Deferred: at `onAppear` the content has not been laid out, so there is
                // nothing yet to scroll to.
                DispatchQueue.main.async {
                    proxy.scrollTo(centreOn, anchor: .center)
                }
            }
        }
    }
}

#Preview("Timeline with history") {
    let viewModel = FactorTrackerViewModel(settings: .defaultSettings)
    // A few weeks of doses, so the chart is wider than the viewport and the day strip
    // has something to slide under the centred-day marker.
    for daysAgo in stride(from: 21, through: 0, by: -3) {
        viewModel.addInjection(
            doseIU: 3000,
            at: Date().addingTimeInterval(-Double(daysAgo) * 86_400),
            lot: "4363501B",
            productName: "Elocta"
        )
    }
    return TimelineView(viewModel: viewModel, onClose: {})
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
