import Foundation

/// In-process mock that fulfils the `HubClient` protocol without any networking.
/// Loads JSON fixtures from the bundle's `Resources/Mocks/` directory.
final class MockHubClient: HubClient, @unchecked Sendable {
    private let bundle: Bundle
    private let decoder: JSONDecoder
    private var nodes: [Plant]
    private let healthFixture: HubHealth
    private let historyFixture: History

    init(bundle: Bundle = .main) {
        self.bundle = bundle
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
        self.nodes = Self.loadJSON([Plant].self, name: "nodes", bundle: bundle, decoder: decoder)
        self.healthFixture = Self.loadJSON(HubHealth.self, name: "health", bundle: bundle, decoder: decoder)
        self.historyFixture = Self.loadJSON(
            History.self,
            name: "history-aabbccddee01-24h",
            bundle: bundle,
            decoder: decoder
        )
    }

    func health() async throws -> HubHealth { healthFixture }
    func listNodes() async throws -> [Plant] { nodes }

    func node(id: String) async throws -> Plant {
        guard let plant = nodes.first(where: { $0.id == id }) else {
            throw HubError(code: "not_found", message: "No node with id \(id)")
        }
        return plant
    }

    func history(id: String, range: History.Range) async throws -> History {
        // The single 24h fixture is reused for all nodes/ranges. For ranges
        // larger than 24h we just return the 24h samples; good enough until
        // hub Phase 3 lands.
        History(nodeId: id, range: range, samples: historyFixture.samples)
    }

    func createNode(_ create: NodeCreate) async throws -> Plant {
        let id = create.mac.replacingOccurrences(of: ":", with: "").lowercased()
        if nodes.contains(where: { $0.id == id }) {
            throw HubError(code: "conflict", message: "Already provisioned")
        }
        let plant = Plant(
            id: id,
            mac: create.mac,
            name: create.name,
            lastSeen: .now,
            online: true,
            batteryPct: 100,
            latest: Reading(timestamp: .now,
                            temperatureC: 22.0,
                            humidityPct: 50.0,
                            pressureHpa: 1013.0,
                            soilPct: 50.0,
                            illuminanceLux: 200.0,
                            batteryPct: 100),
            calibration: create.calibration ?? .default
        )
        nodes.append(plant)
        return plant
    }

    func updateNode(id: String, with update: NodeUpdate) async throws -> Plant {
        guard let idx = nodes.firstIndex(where: { $0.id == id }) else {
            throw HubError(code: "not_found", message: "No node with id \(id)")
        }
        var plant = nodes[idx]
        if let name = update.name { plant.name = name }
        if let cal = update.calibration { plant.calibration = cal }
        nodes[idx] = plant
        return plant
    }

    func deleteNode(id: String) async throws {
        nodes.removeAll { $0.id == id }
    }

    func setupWifi(_ creds: WifiCreds) async throws {
        // No-op in mock.
        _ = creds
    }

    func liveStream() -> AsyncThrowingStream<StreamFrame, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                while !Task.isCancelled {
                    try await Task.sleep(for: .seconds(15))
                    guard let plant = self.nodes.randomElement() else { continue }
                    var reading = plant.latest
                    reading = Reading(
                        timestamp: .now,
                        temperatureC: reading.temperatureC.map { $0 + Double.random(in: -0.2...0.2) },
                        humidityPct: reading.humidityPct.map { $0 + Double.random(in: -0.5...0.5) },
                        pressureHpa: reading.pressureHpa,
                        soilPct: reading.soilPct.map { max(0, $0 - Double.random(in: 0...0.2)) },
                        illuminanceLux: reading.illuminanceLux.map { $0 + Double.random(in: -20...20) },
                        batteryPct: reading.batteryPct
                    )
                    continuation.yield(StreamFrame(type: .reading, nodeId: plant.id, payload: reading))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Fixtures

    private static func loadJSON<T: Decodable>(
        _ type: T.Type,
        name: String,
        bundle: Bundle,
        decoder: JSONDecoder
    ) -> T {
        guard let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Mocks")
                ?? bundle.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            fatalError("Missing mock fixture: \(name).json")
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            fatalError("Failed to decode \(name).json: \(error)")
        }
    }
}
