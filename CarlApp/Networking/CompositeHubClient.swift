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

    /// Hard ceiling on the LAN attempt, enforced independently of whatever
    /// timeout the LAN client's own URLSession is configured with.
    /// `carl-hub.local` resolution goes through the system's mDNS resolver,
    /// which has a documented history of not always honoring
    /// `URLSessionConfiguration.timeoutIntervalForRequest` for `.local`
    /// hostnames — without this backstop, a hub that's unreachable (away
    /// from home) can hang well past its configured timeout and the app
    /// never falls back to Norman, leaving the user stuck on a spinner.
    private static let lanDeadline: Duration = .seconds(5)
    private static let cloudDeadline: Duration = .seconds(12)

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
        lanCall: @escaping @Sendable () async throws -> T,
        cloudCall: @escaping @Sendable (NormanClient) async throws -> T
    ) async throws -> T {
        do {
            return try await Self.withDeadline(Self.lanDeadline, operation: lanCall)
        } catch {
            guard let cloud else { throw error }
            return try await Self.withDeadline(Self.cloudDeadline) { try await cloudCall(cloud) }
        }
    }

    /// Races `operation` against a hard wall-clock deadline. Whichever
    /// finishes first wins; the loser is cancelled. Use this instead of (or
    /// alongside) URLSession-level timeouts whenever the underlying network
    /// path is untrustworthy about honoring its own configured timeout.
    private static func withDeadline<T: Sendable>(
        _ duration: Duration,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: duration)
                throw HubError(code: "timeout", message: "Timed out after \(duration)")
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else {
                throw HubError(code: "timeout", message: "Timed out")
            }
            return result
        }
    }
}
