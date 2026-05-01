import XCTest
@testable import CarlApp

final class MockHubClientTests: XCTestCase {
    func test_listNodes_returnsFixtures() async throws {
        let client = MockHubClient(bundle: Bundle(for: type(of: self)))
        let plants = try await client.listNodes()
        XCTAssertFalse(plants.isEmpty, "Expected at least one plant fixture in nodes.json")
    }

    func test_health_returnsFixture() async throws {
        let client = MockHubClient(bundle: Bundle(for: type(of: self)))
        let health = try await client.health()
        XCTAssertFalse(health.hubId.isEmpty)
    }
}
