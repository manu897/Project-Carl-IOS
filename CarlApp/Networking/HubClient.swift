import Foundation

protocol HubClient: Sendable {
    func health() async throws -> HubHealth
    func listNodes() async throws -> [Plant]
    func node(id: String) async throws -> Plant
    func history(id: String, range: History.Range) async throws -> History
    func createNode(_ create: NodeCreate) async throws -> Plant
    func updateNode(id: String, with update: NodeUpdate) async throws -> Plant
    func deleteNode(id: String) async throws
    func setupWifi(_ creds: WifiCreds) async throws
    func liveStream() -> AsyncThrowingStream<StreamFrame, Error>
}

final class HTTPHubClient: HubClient, @unchecked Sendable {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = .carlHub()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    func health() async throws -> HubHealth {
        try await get("/api/health")
    }

    func listNodes() async throws -> [Plant] {
        try await get("/api/nodes")
    }

    func node(id: String) async throws -> Plant {
        try await get("/api/nodes/\(id)")
    }

    func history(id: String, range: History.Range) async throws -> History {
        try await get("/api/nodes/\(id)/history?range=\(range.rawValue)")
    }

    func createNode(_ create: NodeCreate) async throws -> Plant {
        try await send("POST", "/api/nodes", body: create)
    }

    func updateNode(id: String, with update: NodeUpdate) async throws -> Plant {
        try await send("PATCH", "/api/nodes/\(id)", body: update)
    }

    func deleteNode(id: String) async throws {
        let request = makeRequest("DELETE", "/api/nodes/\(id)")
        let (_, response) = try await session.data(for: request)
        try check(response)
    }

    func setupWifi(_ creds: WifiCreds) async throws {
        let request = try makeRequest("POST", "/api/setup/wifi", body: creds)
        let (_, response) = try await session.data(for: request)
        try check(response)
    }

    func liveStream() -> AsyncThrowingStream<StreamFrame, Error> {
        // /api/stream (WebSocket) is not yet implemented on the hub firmware.
        // Return an empty stream so the app doesn't send an upgrade request that
        // the hub's httpd parser rejects with a 400. Re-enable once the hub
        // ships WebSocket support.
        AsyncThrowingStream { $0.finish() }
    }

    @available(*, unavailable, message: "Re-enable when hub firmware ships /api/stream")
    private func _liveStreamWebSocket() -> AsyncThrowingStream<StreamFrame, Error> {
        AsyncThrowingStream { continuation in
            guard let wsURL = Self.websocketURL(httpBase: baseURL, path: "/api/stream") else {
                continuation.finish(throwing: HubError(
                    code: "bad_ws_scheme",
                    message: "Cannot build WebSocket URL from \(baseURL)"
                ))
                return
            }
            let task = WebSocketStream(
                url: wsURL,
                session: session,
                decoder: decoder,
                continuation: continuation
            )
            continuation.onTermination = { _ in task.cancel() }
            task.start()
        }
    }

    private static func websocketURL(httpBase: URL, path: String) -> URL? {
        guard var components = URLComponents(url: httpBase, resolvingAgainstBaseURL: false) else {
            return nil
        }
        switch components.scheme?.lowercased() {
        case "http", "ws":   components.scheme = "ws"
        case "https", "wss": components.scheme = "wss"
        default:             return nil
        }
        components.path = path
        return components.url
    }

    // MARK: - Private

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let request = makeRequest("GET", path)
        let (data, response) = try await session.data(for: request)
        try check(response)
        return try decoder.decode(T.self, from: data)
    }

    private func send<Body: Encodable, T: Decodable>(_ method: String, _ path: String, body: Body) async throws -> T {
        let request = try makeRequest(method, path, body: body)
        let (data, response) = try await session.data(for: request)
        try check(response)
        return try decoder.decode(T.self, from: data)
    }

    private func makeRequest(_ method: String, _ path: String) -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func makeRequest<Body: Encodable>(_ method: String, _ path: String, body: Body) throws -> URLRequest {
        var request = makeRequest(method, path)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return request
    }

    private func check(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw HubError(code: "no_http_response", message: "Non-HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw HubError(code: "http_\(http.statusCode)", message: HTTPURLResponse.localizedString(forStatusCode: http.statusCode))
        }
    }
}

private final class WebSocketStream: NSObject, URLSessionWebSocketDelegate, @unchecked Sendable {
    private let url: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let continuation: AsyncThrowingStream<StreamFrame, Error>.Continuation
    private var task: URLSessionWebSocketTask?

    init(url: URL,
         session: URLSession,
         decoder: JSONDecoder,
         continuation: AsyncThrowingStream<StreamFrame, Error>.Continuation) {
        self.url = url
        self.session = session
        self.decoder = decoder
        self.continuation = continuation
    }

    func start() {
        task = session.webSocketTask(with: url)
        task?.resume()
        receive()
    }

    func cancel() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    private func receive() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                self.continuation.finish(throwing: error)
            case .success(let message):
                if let frame = self.decode(message) {
                    self.continuation.yield(frame)
                }
                self.receive()
            }
        }
    }

    private func decode(_ message: URLSessionWebSocketTask.Message) -> StreamFrame? {
        let data: Data?
        switch message {
        case .data(let d): data = d
        case .string(let s): data = s.data(using: .utf8)
        @unknown default: data = nil
        }
        guard let data else { return nil }
        return try? decoder.decode(StreamFrame.self, from: data)
    }
}
