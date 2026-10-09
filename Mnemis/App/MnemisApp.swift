import SwiftUI
import SwiftData

@main
struct MnemisApp: App {
    @AppStorage(SettingsKey.hasOnboarded) private var hasOnboarded = false
    private let container = AppEnvironment.makeContainer()

    var body: some Scene {
        WindowGroup {
            Group {
                if hasOnboarded {
                    RootView()
                } else {
                    OnboardingView()
                }
            }
            .task { AppEnvironment.bootstrap(in: container.mainContext) }
        }
        .modelContainer(container)
    }
}
