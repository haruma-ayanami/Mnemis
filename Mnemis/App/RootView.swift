import SwiftUI

/// Корень интерфейса: онбординг при первом запуске, затем пять разделов (ABOUT.md, раздел 15).
struct RootView: View {
    let container: AppContainer
    @Bindable var router: AppRouter
    @Environment(\.scenePhase) private var scenePhase

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
                    // Новая вкладка открывается с развёрнутой панелью: сворачивание относится к прокрутке конкретного экрана.
                    router.setTabBarFolded(false)
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
                    if router.isTabBarVisible {
                        MnemisTabBar(
                            selection: tabSelection,
                            folded: router.isTabBarFolded,
                            onUnfold: { router.expandTabBarByUser() }
                        )
                        .ignoresSafeArea(edges: .bottom)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(Motion.chrome, value: router.isTabBarVisible)
            } else {
                OnboardingView(container: container)
            }
        }
        .tint(AppColor.accent)
        .foregroundStyle(AppColor.ink)
        .background(AppColor.background.ignoresSafeArea())
        // Счётчики «на сегодня» привязаны к дню: после возврата в приложение и при смене дня экраны перечитываются.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { router.requestRefresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            router.requestRefresh()
        }
        .preferredColorScheme(router.colorScheme)
    }
}
