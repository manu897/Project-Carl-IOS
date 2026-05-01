import Foundation

/// Picks the repository implementation at launch time. Default in Debug is the
/// fixture-backed mock so the UI works without a hub on the network.
@MainActor
enum AppEnvironment {
    /// Flip to false to drive a real hub over Bonjour. Real-device only —
    /// Bonjour doesn't work in the iOS Simulator across networks.
    static let useMockHub = true

    static func makeRepository() -> any PlantRepository {
        if useMockHub {
            return HubRepository(client: MockHubClient())
        } else {
            // Real-hub path: HubDiscovery resolves carl-hub.local; until then we
            // fall back to the well-known mDNS hostname so the app boots.
            let url = URL(string: "http://carl-hub.local")!
            return HubRepository(client: HTTPHubClient(baseURL: url))
        }
    }
}
