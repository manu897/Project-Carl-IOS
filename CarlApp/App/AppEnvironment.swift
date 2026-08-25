import Foundation

/// Picks the repository implementation at launch time. The Mock / Real toggle
/// is user-controlled at runtime via `Settings`; see `SettingsKeys.useMockHub`.
@MainActor
enum AppEnvironment {
    static let defaultHubURL = URL(string: "http://carl-hub.local")!
    static let normanBaseURL = URL(string: "https://norman.manideepreddy.com")!

    static func makeRepository(useMockHub: Bool) -> any PlantRepository {
        if useMockHub {
            return HubRepository(client: MockHubClient())
        }
        // Real-hub path: hub advertises _carl-hub._tcp via mDNS, but
        // carl-hub.local resolves correctly on the LAN today so we don't
        // need to spin up NWBrowser for the first deploy.
        guard NormanSession.isSignedIn else {
            return HubRepository(client: HTTPHubClient(baseURL: defaultHubURL))
        }
        // Signed in to Norman: read through CompositeHubClient so plants are
        // visible off-LAN too. Its LAN leg uses a short-timeout session so a
        // missing/off-Wi-Fi hub fails fast and falls back to the cloud
        // instead of hanging on mDNS resolution.
        let lan = HTTPHubClient(baseURL: defaultHubURL, session: HTTPHubClient.lanProbeSession())
        let cloud = NormanClient(baseURL: normanBaseURL)
        return HubRepository(client: CompositeHubClient(lan: lan, cloud: cloud))
    }
}

enum SettingsKeys {
    /// `true` while developing against fixtures; flip from the Settings screen
    /// to talk to the hub at carl-hub.local. Persisted in `UserDefaults`.
    static let useMockHub = "useMockHub"

    /// Master on/off for local notifications about dry soil, low battery, offline nodes.
    static let alertsEnabled = "AlertEngine.enabled"

    /// `[String]` — plant ids the user has muted individually.
    static let alertsMuted = "AlertEngine.mutedPlantIds"

    /// Mirrors `NormanSession.isSignedIn` into `UserDefaults` so `@AppStorage`
    /// in `CarlApp` can force the view tree (and its repository) to rebuild
    /// when the user signs in/out of the cloud account — the same mechanism
    /// already used for the mock/real toggle.
    static let normanSignedIn = "NormanSession.signedIn"
}
