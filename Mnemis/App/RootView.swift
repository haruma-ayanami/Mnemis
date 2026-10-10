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
                    TodayView(container: container)
                        .toolbarVisibility(.hidden, for: .tabBar)
                        .tag(AppTab.today)
                    LearnView(container: container)
                        .toolbarVisibility(.hidden, for: .tabBar)
                        .tag(AppTab.learn)
                    WordsView(container: container)
                        .toolbarVisibility(.hidden, for: .tabBar)
                        .tag(AppTab.words)
                    StatisticsView(container: container)
                        .toolbarVisibility(.hidden, for: .tabBar)
                        .tag(AppTab.statistics)
                    SettingsView(container: container)
                        .toolbarVisibility(.hidden, for: .tabBar)
                        .tag(AppTab.settings)
                }
                // Системная панель скрыта: вместо неё панель из холста — стекло, пять пунктов, активный серый.
                // Содержимое поднимается над панелью; сама панель стоит на 22 pt от края экрана, как в холсте.
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Color.clear.frame(height: 74)
                }
                .overlay(alignment: .bottom) {
                    MnemisTabBar(selection: tabSelection)
                        .ignoresSafeArea(edges: .bottom)
                }
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
