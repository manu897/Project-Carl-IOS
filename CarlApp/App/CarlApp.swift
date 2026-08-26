import SwiftUI
import BackgroundTasks

@main
struct CarlApp: App {
    static let backgroundTaskID = "com.projectcarl.CarlApp.alerts"

    @AppStorage(SettingsKeys.useMockHub) private var useMockHub: Bool = true
    @AppStorage(SettingsKeys.normanSignedIn) private var normanSignedIn: Bool = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            HomeView(viewModel: HomeViewModel(
                repository: AppEnvironment.makeRepository(useMockHub: useMockHub),
                cachingEnabled: !useMockHub
            ))
                // Force the view tree (and thus HomeViewModel + its repository)
                // to recreate when the data source flips, or when signing in/out
                // of the cloud account changes whether reads fall back to it.
                // Simpler than observing & re-injecting through every level.
                .id("\(useMockHub)-\(normanSignedIn)")
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .background {
                        scheduleAlertsRefresh()
                    }
                }
        }
        .backgroundTask(.appRefresh(Self.backgroundTaskID)) {
            await runBackgroundAlertsRefresh()
        }
    }

    /// Background refresh entry point. iOS calls this when it decides to wake
    /// the app (typically every ~30 min while the device is in use, less often
    /// while idle). We fetch /api/nodes, run the alert engine, and reschedule
    /// the next refresh so the chain keeps going.
    @MainActor
    private func runBackgroundAlertsRefresh() async {
        // Match the current user choice — if they're on mock, no background
        // hub call. Real hub on LAN means we may not be reachable while away;
        // a failed fetch is silently absorbed.
        let useMock = UserDefaults.standard.bool(forKey: SettingsKeys.useMockHub)
        let repo = AppEnvironment.makeRepository(useMockHub: useMock)
        do {
            let plants = try await repo.plants()
            await AlertEngine.shared.evaluate(plants)
        } catch {
            // Likely off-LAN; nothing to do. The next foreground refresh will
            // re-evaluate when the user opens the app.
        }
        scheduleAlertsRefresh()
    }

    private func scheduleAlertsRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundTaskID)
        // Earliest iOS may wake us: 30 min from now. Apple decides the actual
        // cadence based on usage; this is a floor, not a guarantee.
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
