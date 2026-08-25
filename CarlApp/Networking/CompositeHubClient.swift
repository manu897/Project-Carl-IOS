import Foundation

/// Reads try the hub on the local network first, falling back to the Norman
/// cloud API when the hub isn't reachable (away from home Wi-Fi, hub
/// offline). Writes — provisioning a plant, renaming, deleting, Wi-Fi setup —
/// always go straight to the hub: those actions only make sense while
/// actually on the hub's network (QR scan proximity, captive portal), and
/// Norman doesn't implement them.
final class CompositeHubClient: HubClient, @unchecked Sendable {
    private let lan: HubClient
    private let cloud: NormanClient?

    init(lan: HubClient, cloud: NormanClient?) {
        self.lan = lan
        self.cloud = cloud
    }

    func health() async throws -> HubHealth {
        try await readWithFallback { try await self.lan.health() } cloudCall: { try await $0.health() }
    }

    func listNodes() async throws -> [Plant] {
        try await readWithFallback { try await self.lan.listNodes() } cloudCall: { try await $0.listNodes() }
    }

    func node(id: String) async throws -> Plant {
        try await readWithFallback { try await self.lan.node(id: id) } cloudCall: { try await $0.node(id: id) }
    }

    func history(id: String, range: History.Range) async throws -> History {
        try await readWithFallback { try await self.lan.history(id: id, range: range) } cloudCall: { try await $0.history(id: id, range: range) }
    }

    func createNode(_ create: NodeCreate) async throws -> Plant {
        try await lan.createNode(create)
    }

    func updateNode(id: String, with update: NodeUpdate) async throws -> Plant {
        try await lan.updateNode(id: id, with: update)
    }

    func deleteNode(id: String) async throws {
        try await lan.deleteNode(id: id)
    }

    func setupWifi(_ creds: WifiCreds) async throws {
        try await lan.setupWifi(creds)
    }

    func liveStream() -> AsyncThrowingStream<StreamFrame, Error> {
        // Live push only makes sense on the LAN; off-network the cloud has no
        // equivalent, so callers rely on pull-to-refresh either way.
        lan.liveStream()
    }

    // MARK: - Private

    private func readWithFallback<T: Sendable>(
        lanCall: () async throws -> T,
        cloudCall: (NormanClient) async throws -> T
    ) async throws -> T {
        do {
            return try await lanCall()
        } catch {
            guard let cloud else { throw error }
            return try await cloudCall(cloud)
        }
    }
}
