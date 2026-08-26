import Foundation

/// Talks to the Norman cloud API (`/v1/...`) as the off-LAN fallback for
/// reading plant data. Norman intentionally mirrors the hub's `Node`/
/// `Reading`/`History` JSON shapes (see `Project-Norman/docs/api.md`), so the
/// same `Plant`/`Reading`/`History` models decode both.
///
/// Write operations (provisioning, Wi-Fi setup) aren't part of Norman's
/// contract — those require being on the hub's own LAN — so they throw a
/// friendly "unsupported" error instead of hitting a 404.
final class NormanClient: HubClient, @unchecked Sendable {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(baseURL: URL, session: URLSession = NormanClient.defaultSession()) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = .carlHub()
    }

    /// `.shared` defaults to a 60s request timeout — too long to sit on for a
    /// cloud request. `CompositeHubClient` already races this against its own
    /// hard deadline, but a sane session-level timeout is worth having
    /// independently (e.g. if `NormanClient` is ever used directly).
    static func defaultSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        return URLSession(configuration: config)
    }

    func health() async throws -> HubHealth {
        throw HubError(code: "unsupported", message: "Hub status isn't available over the cloud.")
    }

    func listNodes() async throws -> [Plant] {
        try await get("/v1/nodes")
    }

    func node(id: String) async throws -> Plant {
        try await get("/v1/nodes/\(id)")
    }

    func history(id: String, range: History.Range) async throws -> History {
        try await get("/v1/nodes/\(id)/history?range=\(range.rawValue)")
    }

    func createNode(_ create: NodeCreate) async throws -> Plant {
        throw HubError(code: "unsupported", message: "Connect to your hub's Wi-Fi to add a plant.")
    }

    func updateNode(id: String, with update: NodeUpdate) async throws -> Plant {
        throw HubError(code: "unsupported", message: "Connect to your hub's Wi-Fi to edit a plant.")
    }

    func deleteNode(id: String) async throws {
        throw HubError(code: "unsupported", message: "Connect to your hub's Wi-Fi to remove a plant.")
    }

    func setupWifi(_ creds: WifiCreds) async throws {
        throw HubError(code: "unsupported", message: "Wi-Fi setup requires connecting to the hub directly.")
    }

    func liveStream() -> AsyncThrowingStream<StreamFrame, Error> {
        // No live push from the cloud; callers fall back to pull-to-refresh.
        AsyncThrowingStream { $0.finish() }
    }

    // MARK: - Private

    private func get<T: Decodable>(_ path: String) async throws -> T {
        guard let token = NormanSession.token else {
            throw HubError(code: "unauthenticated", message: "Sign in to view plants away from home Wi-Fi.")
        }
        var request = URLRequest(url: baseURL.appendingCarlPath(path))
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try check(response)
        return try decoder.decode(T.self, from: data)
    }

    private func check(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw HubError(code: "no_http_response", message: "Non-HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 {
                throw HubError(code: "unauthenticated", message: "Your session expired — sign in again.")
            }
            throw HubError(code: "http_\(http.statusCode)", message: HTTPURLResponse.localizedString(forStatusCode: http.statusCode))
        }
    }
}
