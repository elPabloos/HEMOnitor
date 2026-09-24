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

    /// The day the chart is scrolled to, derived from the list's scroll position.
    /// Changing it scrolls the chart; the user can also scroll the chart by hand,
    /// which leaves this alone.
    @State private var focusedDay: Date?

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
        ScrollViewReader { chartProxy in
            ScrollView(.horizontal) {
                TimelineCurveChart(points: points, range: range)
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity)
            .frame(height: chartHeight)
            .onAppear {
                // Opens on today, at the right-hand edge.
                if let today = range.days().last {
                    chartProxy.scrollTo(today, anchor: .trailing)
                }
            }
            .onChange(of: focusedDay) { _, day in
                guard let day else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    chartProxy.scrollTo(day, anchor: .center)
                }
            }
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
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(chartAccessibilityLabel)
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
            .onPreferenceChange(TimelineScrollOffsetKey.self) { metrics in
                updateFocusedDay(metrics)
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
    private func updateFocusedDay(_ metrics: TimelineScrollMetrics) {
        let days = range.days()
        guard !days.isEmpty else { return }

        let index = TimelineCurve.focusedDayIndex(
            scrollOffset: metrics.offset,
            contentHeight: metrics.contentHeight,
            viewportHeight: metrics.viewportHeight,
            dayCount: days.count
        )
        focusedDay = days[index]
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
/// scroll-progress calculation, and guessing it is what broke the coupling before.
private struct TimelineScrollMetrics: Equatable {
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
