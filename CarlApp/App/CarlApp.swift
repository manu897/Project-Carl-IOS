import SwiftUI

@main
struct CarlApp: App {
    private let repository: any PlantRepository

    init() {
        self.repository = AppEnvironment.makeRepository()
    }

    var body: some Scene {
        WindowGroup {
            HomeView(viewModel: HomeViewModel(repository: repository))
        }
    }
}
