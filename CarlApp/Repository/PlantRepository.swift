import Foundation

protocol PlantRepository: Sendable {
    func plants() async throws -> [Plant]
    func plant(id: String) async throws -> Plant
    func history(id: String, range: History.Range) async throws -> History

    func add(mac: String, keyHex: String, name: String, nodeType: NodeType?,
             roomId: String?, calibration: Calibration?) async throws -> Plant
    func rename(id: String, to name: String) async throws -> Plant
    func updateCalibration(id: String, _ calibration: Calibration) async throws -> Plant
    func remove(id: String) async throws

    /// Push live reading updates from the hub. Stream may end if the hub goes
    /// away; callers are responsible for re-subscribing.
    func liveUpdates() -> AsyncThrowingStream<StreamFrame, Error>
}

/// Default repository: routes every call to the underlying HubClient.
/// Adding a CompositeRepository (LAN/cloud failover) is a follow-up — for MVP
/// we ship one repo per environment, picked at app launch.
final class HubRepository: PlantRepository, @unchecked Sendable {
    private let client: HubClient

    init(client: HubClient) {
        self.client = client
    }

    func plants() async throws -> [Plant] {
        try await client.listNodes()
    }

    func plant(id: String) async throws -> Plant {
        try await client.node(id: id)
    }

    func history(id: String, range: History.Range) async throws -> History {
        try await client.history(id: id, range: range)
    }

    func add(mac: String, keyHex: String, name: String, nodeType: NodeType? = nil,
             roomId: String? = nil, calibration: Calibration? = nil) async throws -> Plant {
        try await client.createNode(NodeCreate(
            mac: mac, keyHex: keyHex, name: name,
            nodeType: nodeType, roomId: roomId, calibration: calibration
        ))
    }

    func rename(id: String, to name: String) async throws -> Plant {
        try await client.updateNode(id: id, with: NodeUpdate(name: name))
    }

    func updateCalibration(id: String, _ calibration: Calibration) async throws -> Plant {
        try await client.updateNode(id: id, with: NodeUpdate(calibration: calibration))
    }

    func remove(id: String) async throws {
        try await client.deleteNode(id: id)
    }

    func liveUpdates() -> AsyncThrowingStream<StreamFrame, Error> {
        client.liveStream()
    }
}
