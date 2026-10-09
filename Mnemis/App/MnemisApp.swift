import SwiftUI

@main
struct MnemisApp: App {
    @State private var container: AppContainer?

    var body: some Scene {
        WindowGroup {
            // Пока хранилище открывается, виден фон приложения того же цвета, что и экран запуска.
            ZStack {
                AppColor.background.ignoresSafeArea()
                if let container {
                    RootView(container: container)
                        .task { await container.refreshNotifications() }
                        .transition(.opacity)
                }
            }
            .animation(Motion.enter, value: container == nil)
            .task { await start() }
        }
    }

    private func start() async {
        guard container == nil else { return }
        do {
            container = try await AppContainer.launch()
        } catch {
            fatalError("Could not start Mnemis: \(error)")
        }
    }
}
