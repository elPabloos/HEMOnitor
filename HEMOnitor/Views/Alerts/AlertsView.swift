//
//  AlertsView.swift
//  HEMOnitor
//

import SwiftUI

/// Level-crossing alerts: a threshold, how much warning to give, and an optional
/// nudge if nothing gets logged afterwards.
struct AlertsView: View {
    @ObservedObject var viewModel: AlertsViewModel

    private static let leadTimeOptions: [Double] = [1, 2, 4, 6, 12, 24]
    private static let followUpOptions: [Double] = [1, 2, 4, 8]

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.stackGapLarge) {
                mainCard
                if viewModel.authorization == .denied { deniedNotice }
                if viewModel.settings.remindersEnabled { scheduledCard }
                disclaimer
            }
            .padding(.horizontal, Theme.Spacing.screenGutter)
            .padding(.vertical, Theme.Spacing.stackGap)
        }
        .task { await viewModel.refreshAuthorization() }
    }

    // MARK: - Main card

    private var mainCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.stackGap) {
            HStack(alignment: .top, spacing: Theme.Spacing.stackGap) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Level alerts")
                        .font(AppTextStyle.headline)
                        .foregroundStyle(AppColor.ink)
                    Text("Get notified before your estimated level drops below a threshold.")
                        .font(AppTextStyle.caption)
                        .foregroundStyle(AppColor.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Toggle("", isOn: Binding(
                    get: { viewModel.settings.remindersEnabled },
                    set: { newValue in Task { await viewModel.setRemindersEnabled(newValue) } }
                ))
                .labelsHidden()
                .tint(AppColor.primaryGreen)
                .accessibilityLabel("Level alerts")
            }

            if viewModel.settings.remindersEnabled {
                Divider().overlay(AppColor.ink.opacity(0.08))
                thresholdSection
                leadTimeSection
                Divider().overlay(AppColor.ink.opacity(0.08))
                followUpSection
            }
        }
        .glassCard()
    }

    private var thresholdSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Alert threshold")
                    .font(AppTextStyle.caption)
                    .foregroundStyle(AppColor.inkSecondary)
                Spacer()
                Text("\(Int(viewModel.settings.crossingThresholdPercent))%")
                    .font(.plexMono(20, weight: .bold))
                    .foregroundStyle(AppColor.primaryGreen)
            }
            Slider(
                value: Binding(
                    get: { viewModel.settings.crossingThresholdPercent },
                    set: { newValue in Task { await viewModel.setThreshold(newValue) } }
                ),
                in: 5...60,
                step: 5
            )
            .tint(AppColor.primaryGreen)
            .accessibilityValue("\(Int(viewModel.settings.crossingThresholdPercent)) percent")
            HStack {
                Text("5%")
                Spacer()
                Text("60%")
            }
            .font(.plexMono(11, weight: .medium))
            .foregroundStyle(AppColor.inkTertiary)
        }
    }

    private var leadTimeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Warn me this far ahead")
                    .font(AppTextStyle.caption)
                    .foregroundStyle(AppColor.inkSecondary)
                Spacer()
                Text(hoursLabel(viewModel.settings.leadTimeHours))
                    .font(.plexMono(13, weight: .bold))
                    .foregroundStyle(AppColor.primaryGreen)
            }
            chipRow(
                options: Self.leadTimeOptions,
                selected: viewModel.settings.leadTimeHours
            ) { hours in
                Task { await viewModel.setLeadTime(hours: hours) }
            }
        }
    }

    private var followUpSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: Theme.Spacing.stackGap) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Missed dose follow-up")
                        .font(AppTextStyle.bodyEmphasis)
                        .foregroundStyle(AppColor.ink)
                    Text("Remind me again if nothing is logged after the crossing.")
                        .font(AppTextStyle.caption)
                        .foregroundStyle(AppColor.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Toggle("", isOn: Binding(
                    get: { viewModel.settings.missedDoseFollowUpEnabled },
                    set: { newValue in Task { await viewModel.setMissedDoseFollowUp(enabled: newValue) } }
                ))
                .labelsHidden()
                .tint(AppColor.primaryGreen)
                .accessibilityLabel("Missed dose follow-up")
            }

            if viewModel.settings.missedDoseFollowUpEnabled {
                chipRow(
                    options: Self.followUpOptions,
                    selected: viewModel.settings.missedDoseFollowUpHours
                ) { hours in
                    Task { await viewModel.setMissedDoseFollowUp(hours: hours) }
                }
            }
        }
    }

    private func chipRow(
        options: [Double],
        selected: Double,
        onSelect: @escaping (Double) -> Void
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(options, id: \.self) { hours in
                    let isSelected = hours == selected
                    Button { onSelect(hours) } label: {
                        Text(hoursLabel(hours))
                            .font(.plexMono(13, weight: .bold))
                            .foregroundStyle(isSelected ? .white : AppColor.ink)
                            .padding(.horizontal, 14)
                            .frame(minWidth: 48, minHeight: 44)
                            .background(
                                isSelected ? AnyShapeStyle(AppColor.primaryGreen) : AnyShapeStyle(AppColor.glassFillStrong),
                                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(.horizontal, 1)
        }
    }

    // MARK: - Supporting views

    /// Permission can only be restored from iOS Settings, so say so rather than
    /// letting the toggle silently fail.
    private var deniedNotice: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Notifications are turned off")
                .font(AppTextStyle.bodyEmphasis)
                .foregroundStyle(AppColor.warningForeground)
            Text("HEMOnitor can't send alerts until you allow notifications in iOS Settings.")
                .font(AppTextStyle.caption)
                .foregroundStyle(AppColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Link("Open Settings", destination: url)
                    .font(AppTextStyle.bodyEmphasis)
                    .foregroundStyle(AppColor.primaryGreen)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var scheduledCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.stackGap) {
            Text("Scheduled")
                .font(AppTextStyle.kicker)
                .foregroundStyle(AppColor.inkSecondary)

            if viewModel.scheduled.isEmpty {
                Text("Nothing scheduled — your level isn't predicted to cross the threshold, or there's no dose to decay from.")
                    .font(AppTextStyle.caption)
                    .foregroundStyle(AppColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(viewModel.scheduled) { alert in
                    HStack(spacing: Theme.Spacing.stackGap) {
                        Circle()
                            .fill(alert.kind == .crossing ? AppColor.zonePartial : AppColor.inkTertiary)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(AlertSchedule.title(for: alert.kind))
                                .font(AppTextStyle.bodyEmphasis)
                                .foregroundStyle(AppColor.ink)
                            Text(alert.fireDate.formatted(date: .abbreviated, time: .shortened))
                                .font(AppTextStyle.caption)
                                .foregroundStyle(AppColor.inkSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var disclaimer: some View {
        Text("Alerts fire on the predicted curve, not a measurement. Your real level can differ from the estimate.")
            .font(.jakarta(11.5, weight: .regular))
            .foregroundStyle(AppColor.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
    }

    private func hoursLabel(_ hours: Double) -> String {
        hours >= 24 ? "\(Int(hours / 24))d" : "\(Int(hours))h"
    }
}

#Preview {
    AlertsView(viewModel: AlertsViewModel())
        .background(AppColor.backgroundGradient)
}
