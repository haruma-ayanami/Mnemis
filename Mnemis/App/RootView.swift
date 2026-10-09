import SwiftUI

/// Корень интерфейса: онбординг при первом запуске, затем пять разделов (ABOUT.md, раздел 15).
struct RootView: View {
    let container: AppContainer
    @Bindable var router: AppRouter

    init(container: AppContainer) {
        self.container = container
        self.router = container.router
    }

    /// Выбор вкладки. Нажатие на уже открытую вкладку не меняет её, а сообщает экрану о повторном нажатии.
    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { router.selectedTab },
            set: { tab in
                if tab == router.selectedTab {
                    router.reselect(tab)
                } else {
                    router.selectedTab = tab
                }
            }
        )
    }

    var body: some View {
        Group {
            if router.isOnboarded {
                TabView(selection: tabSelection) {
                    Tab("Today", systemImage: "sun.max", value: AppTab.today) {
                        TodayView(container: container)
                    }
                    Tab("Learn", systemImage: "rectangle.stack", value: AppTab.learn) {
                        LearnView(container: container)
                    }
                    Tab("Words", systemImage: "character.book.closed", value: AppTab.words) {
                        WordsView(container: container)
                    }
                    Tab("Statistics", systemImage: "chart.bar", value: AppTab.statistics) {
                        StatisticsView(container: container)
                    }
                    Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                        SettingsView(container: container)
                    }
                }
                // При прокрутке вниз панель сжимается до текущей вкладки, при прокрутке вверх раскрывается.
                .tabBarMinimizeBehavior(.onScrollDown)
            } else {
                OnboardingView(container: container)
            }
        }
        .tint(AppColor.accent)
        .foregroundStyle(AppColor.ink)
        .background(AppColor.background.ignoresSafeArea())
        .preferredColorScheme(router.colorScheme)
    }
}
