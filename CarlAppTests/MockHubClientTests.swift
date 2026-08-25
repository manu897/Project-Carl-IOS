import XCTest
@testable import CarlApp

// CarlAppTests is a hosted test bundle (TEST_HOST = CarlApp.app), so the
// fixture JSON that's bundled into the app — not the .xctest bundle — is
// reachable via `.main` here.
final class MockHubClientTests: XCTestCase {
    func test_listNodes_returnsFixtures() async throws {
        let client = MockHubClient(bundle: .main)
        let plants = try await client.listNodes()
        XCTAssertFalse(plants.isEmpty, "Expected at least one plant fixture in nodes.json")
    }

    func test_health_returnsFixture() async throws {
        let client = MockHubClient(bundle: .main)
        let health = try await client.health()
        XCTAssertFalse(health.hubId.isEmpty)
    }
}
