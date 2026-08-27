import Foundation

/// Picks the repository implementation at launch time. The Mock / Real toggle
/// is user-controlled at runtime via `Settings`; see `SettingsKeys.useMockHub`.
@MainActor
enum AppEnvironment {
    static let defaultHubURL = URL(string: "http://carl-hub.local")!
    static let normanBaseURL = URL(string: "https://norman.manideepreddy.com")!

    // Shared, long-lived sessions — reused across every repository build so
    // navigating between screens doesn't pay a fresh TLS handshake each
    // time. `URLSession` keeps its own connection pool alive as long as the
    // same instance is reused; the previous code called `HTTPHubClient
    // .lanProbeSession()`/`NormanClient.defaultSession()` fresh inside
    // `makeRepository` on every call (once per screen — Home, every
    // PlantDetailView, background refresh), which threw the pool away and
    // paid a new TLS handshake to Norman on every navigation. Measured
    // impact: Norman is US-hosted (GCP us-central1), so each handshake costs
    // real round-trip time on top of whatever the request itself needed.
    private static let lanSession = HTTPHubClient.lanProbeSession()
    private static let normanSession = NormanClient.defaultSession()

    static func makeRepository(useMockHub: Bool) -> any PlantRepository {
        if useMockHub {
            return HubRepository(client: MockHubClient())
        }
        // Real-hub path: hub advertises _carl-hub._tcp via mDNS, but
        // carl-hub.local resolves correctly on the LAN today so we don't
        // need to spin up NWBrowser for the first deploy.
        //
        // ALWAYS route through CompositeHubClient with the short-timeout LAN
        // session, signed in or not. `carl-hub.local` is mDNS — it cannot
        // resolve off the home network at all, and on some Wi-Fi setups
        // mDNS resolution is itself intermittent (router-dependent, flaky
        // right after the hub reboots or the phone reconnects to Wi-Fi).
        // A bare `HTTPHubClient(baseURL:)` defaults to `URLSession.shared`,
        // whose `waitsForConnectivity = true` config means a request that
        // can never resolve doesn't fail fast — it can hang far longer than
        // any expected timeout, which is exactly the "keeps on loading"
        // symptom this caused both on cellular (no fallback existed at all)
        // and, intermittently, on Wi-Fi (no timeout protection against a
        // flaky mDNS response). Cloud fallback is nil when signed out, so a
        // signed-out user still gets a fast, clear failure instead of a
        // fast success — CompositeHubClient.readWithFallback rethrows the
        // original LAN error when `cloud` is nil.
        let lan = HTTPHubClient(baseURL: defaultHubURL, session: lanSession)
        let cloud = NormanSession.isSignedIn ? NormanClient(baseURL: normanBaseURL, session: normanSession) : nil
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
