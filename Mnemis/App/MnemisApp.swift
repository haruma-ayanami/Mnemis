import SwiftUI

@main
struct MnemisApp: App {
    @State private var container: AppContainer

    init() {
        do {
            let container = try AppContainer.live()
            container.bootstrap()
            _container = State(initialValue: container)
        } catch {
            fatalError("Could not start Mnemis: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
                .task { await container.refreshNotifications() }
        }
    }
}
