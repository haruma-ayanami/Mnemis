import SwiftUI

/// Настройки уведомлений (ABOUT.md, раздел 17): пользователь управляет включением, временем, типами и частотой.
struct NotificationSettingsView: View {
    let viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    private let weekdayLetters = ["M", "T", "W", "T", "F", "S", "S"]
    private let weekdayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    private var enabled: Bool { viewModel.settings.dailyReminderEnabled }

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    topBar
                    master
                    VStack(alignment: .leading, spacing: 14) {
                        types
                        schedule
                        preview
                    }
                    .opacity(enabled ? 1 : 0.4)
                    .disabled(!enabled)
                    .animation(.smooth, value: enabled)
                }
                .padding(.horizontal, 20).padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .mnemisNavigationBarHidden()
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            RoundGlassButton(systemImage: "chevron.left", label: "Back to Settings") { dismiss() }
            VStack(alignment: .leading, spacing: 2) {
                Text("Notifications").font(.system(size: 26, weight: .semibold)).tracking(-0.6).foregroundStyle(AppColor.ink)
                Text(viewModel.notificationSummary).font(.system(size: 11, design: .monospaced)).foregroundStyle(AppColor.smoke)
            }
        }
        .padding(.top, 8)
    }

    private var master: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(get: { enabled }, set: { viewModel.setNotificationsEnabled($0) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Allow notifications").font(.system(size: 16)).foregroundStyle(AppColor.ink)
                    Text("local only · no account needed").font(.system(size: 12, design: .monospaced)).foregroundStyle(AppColor.smoke)
                }
            }
            .toggleStyle(GlowToggleStyle())
            .padding(.horizontal, 16).frame(minHeight: 60)
            .glassCard(cornerRadius: 22)
            if enabled && !viewModel.notificationsAuthorized {
                Text("Notifications are blocked in system settings. Allow them there to receive reminders.")
                    .font(.system(size: 12)).foregroundStyle(AppColor.ash).padding(.horizontal, 6)
            }
        }
        .padding(.top, 6)
    }

    private var types: some View {
        SettingsGroup(title: "Types") {
            typeRow(.wordOfDay, "Word of the day", "a new word to guess", viewModel.settings.dailyReminderMinutes)
            typeRow(.reviews, "Reviews ready", "when words are due", NotificationPlanner.reviewsMinutes)
            typeRow(.streak, "Streak reminder", "only if you skipped today", NotificationPlanner.streakMinutes)
        }
    }

    private func typeRow(_ kind: NotificationKind, _ title: LocalizedStringKey, _ subtitle: LocalizedStringKey, _ minutes: Int) -> some View {
        Toggle(isOn: Binding(get: { viewModel.isNotify(kind) }, set: { viewModel.setNotify(kind, $0) })) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 16)).foregroundStyle(AppColor.ink)
                    Text(subtitle).font(.system(size: 12, design: .monospaced)).foregroundStyle(AppColor.smoke)
                }
                Spacer(minLength: 4)
                if kind == .wordOfDay {
                    DatePicker("Time", selection: wordTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                } else {
                    Text(String(format: "%02d:%02d", minutes / 60, minutes % 60))
                        .font(.system(size: 13, design: .monospaced)).foregroundStyle(AppColor.ink)
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(AppColor.hairline, in: .rect(cornerRadius: 10))
                }
            }
        }
        .toggleStyle(GlowToggleStyle())
        .padding(.horizontal, 16).frame(minHeight: 58)
    }

    private var wordTime: Binding<Date> {
        Binding(
            get: {
                let minutes = viewModel.settings.dailyReminderMinutes
                return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                viewModel.setWordTime(minutes: (parts.hour ?? 9) * 60 + (parts.minute ?? 0))
            }
        )
    }

    private var schedule: some View {
        SettingsGroup(title: "Schedule") {
            HStack {
                ForEach(0..<7, id: \.self) { index in
                    let on = viewModel.isWeekdayOn(index)
                    Button { viewModel.toggleWeekday(index) } label: {
                        Text(weekdayLetters[index])
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(on ? AppColor.onFill : AppColor.ash)
                            .frame(width: 36, height: 36)
                            .background(on ? AppColor.fill : .clear, in: .circle)
                            .overlay(Circle().stroke(on ? .clear : AppColor.hairline))
                    }
                    .buttonStyle(PressScaleStyle())
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(Text(LocalizedStringKey(weekdayNames[index])))
                    .accessibilityAddTraits(on ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, 10).frame(minHeight: 58)

            SettingsRow(title: "Quiet hours", subtitle: "nothing is sent at night") {
                Text("22:00 – 08:00")
                    .font(.system(size: 13, design: .monospaced)).foregroundStyle(AppColor.ink)
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(AppColor.hairline, in: .rect(cornerRadius: 10))
            }

            SettingsRow(title: "At most per day") {
                HStack(spacing: 2) {
                    ForEach(1...3, id: \.self) { count in
                        let on = viewModel.settings.maxNotificationsPerDay == count
                        Button { viewModel.setMaxPerDay(count) } label: {
                            Text("\(count)")
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundStyle(on ? AppColor.ink : AppColor.ash)
                                .frame(width: 40, height: 30)
                                .background(on ? AppColor.hairline : .clear, in: .capsule)
                        }
                        .buttonStyle(PressScaleStyle())
                        .accessibilityAddTraits(on ? [.isSelected] : [])
                    }
                }
                .padding(2)
                .background(AppColor.hairline.opacity(0.5), in: .capsule)
            }
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preview").bracketLabel().padding(.leading, 6)
            SamplePush(
                kind: "MNEMIS · WORD OF THE DAY",
                time: String(format: "%02d:%02d", viewModel.settings.dailyReminderMinutes / 60, viewModel.settings.dailyReminderMinutes % 60),
                title: "accomplish",
                message: "/əˈkʌmplɪʃ/ · guess the meaning, then hold to reveal."
            )
        }
    }
}
