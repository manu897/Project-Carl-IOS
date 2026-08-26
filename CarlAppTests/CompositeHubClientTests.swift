import XCTest
@testable import CarlApp

/// A `HubClient` that never returns from `listNodes()` — standing in for
/// `carl-hub.local` mDNS resolution hanging past its configured
/// `URLSessionConfiguration` timeout, which is what actually happened in the
/// field: the LAN leg never threw, so `CompositeHubClient` never fell back
/// to Norman, and the user was stuck on "Looking for plants…" forever.
private final class HangingHubClient: HubClient, @unchecked Sendable {
    func health() async throws -> HubHealth { throw HubError(code: "unused", message: "unused") }

    func listNodes() async throws -> [Plant] {
        try await Task.sleep(for: .seconds(30))
        return []
    }

    func node(id: String) async throws -> Plant { throw HubError(code: "unused", message: "unused") }
    func history(id: String, range: History.Range) async throws -> History { throw HubError(code: "unused", message: "unused") }
    func createNode(_ create: NodeCreate) async throws -> Plant { throw HubError(code: "unused", message: "unused") }
    func updateNode(id: String, with update: NodeUpdate) async throws -> Plant { throw HubError(code: "unused", message: "unused") }
    func deleteNode(id: String) async throws {}
    func setupWifi(_ creds: WifiCreds) async throws {}
    func liveStream() -> AsyncThrowingStream<StreamFrame, Error> { AsyncThrowingStream { $0.finish() } }
}

final class CompositeHubClientTests: XCTestCase {
    func test_hangingLANCall_failsWithinTheDeadline_insteadOfHangingForever() async throws {
        let client = CompositeHubClient(lan: HangingHubClient(), cloud: nil)
        let start = Date()

        do {
            _ = try await client.listNodes()
            XCTFail("Expected the hard deadline to fire since the LAN call never returns and there's no cloud fallback.")
        } catch {
            let elapsed = Date().timeIntervalSince(start)
            XCTAssertLessThan(elapsed, 8, "The LAN leg must give up well under its 5s deadline, not hang indefinitely.")
        }
    }
}
