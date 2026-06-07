import Foundation

/// Picks the repository implementation at launch time. The Mock / Real toggle
/// is user-controlled at runtime via `Settings`; see `SettingsKeys.useMockHub`.
@MainActor
enum AppEnvironment {
    static let defaultHubURL = URL(string: "http://carl-hub.local")!

    static func makeRepository(useMockHub: Bool) -> any PlantRepository {
        if useMockHub {
            return HubRepository(client: MockHubClient())
        } else {
            // Real-hub path: hub advertises _carl-hub._tcp via mDNS, but
            // carl-hub.local resolves correctly on the LAN today so we don't
            // need to spin up NWBrowser for the first deploy.
            return HubRepository(client: HTTPHubClient(baseURL: defaultHubURL))
        }
    }
}

enum SettingsKeys {
    /// `true` while developing against fixtures; flip from the Settings screen
    /// to talk to the hub at carl-hub.local. Persisted in `UserDefaults`.
    static let useMockHub = "useMockHub"
}
