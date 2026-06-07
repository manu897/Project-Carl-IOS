import SwiftUI

@main
struct CarlApp: App {
    @AppStorage(SettingsKeys.useMockHub) private var useMockHub: Bool = true

    var body: some Scene {
        WindowGroup {
            HomeView(viewModel: HomeViewModel(repository: AppEnvironment.makeRepository(useMockHub: useMockHub)))
                // Force the view tree (and thus HomeViewModel + its repository)
                // to recreate when the data source flips. Simpler than
                // observing & re-injecting through every level.
                .id(useMockHub)
        }
    }
}
