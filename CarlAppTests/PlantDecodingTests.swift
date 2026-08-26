import XCTest
@testable import CarlApp

/// Norman's schema allows `last_seen` and `latest` to be null for a node
/// that hasn't reported a reading yet (unlike the hub's own contract, where
/// both are always present). `Plant`'s decoder must tolerate that — one
/// quiet node shouldn't fail decoding the whole `/v1/nodes` array and blank
/// out every other plant in the list.
final class PlantDecodingTests: XCTestCase {
    func test_decodesSuccessfully_whenLastSeenAndLatestAreNull() throws {
        let json = """
        {
            "id": "hub-002-newnode",
            "mac": "AA:BB:CC:DD:EE:99",
            "name": "Just Added",
            "node_type": "plant",
            "room_id": "",
            "online": false,
            "last_seen": null,
            "latest": null
        }
        """.data(using: .utf8)!

        let plant = try JSONDecoder.carlHub().decode(Plant.self, from: json)

        XCTAssertEqual(plant.id, "hub-002-newnode")
        XCTAssertEqual(plant.lastSeen, .distantPast)
        XCTAssertNil(plant.latest.soilPct)
        XCTAssertEqual(plant.status(), .offline, "A never-reported node should read as offline, not crash decoding.")
    }

    func test_decodesArray_whenOneNodeIsIncompleteAmongHealthyOnes() throws {
        let json = """
        [
            {
                "id": "healthy-plant",
                "mac": "AA:BB:CC:DD:EE:01",
                "name": "Bedroom Monstera",
                "node_type": "plant",
                "room_id": "",
                "online": true,
                "last_seen": "2026-08-25T10:00:00Z",
                "latest": { "ts": "2026-08-25T10:00:00Z", "soil_pct": 42.0 }
            },
            {
                "id": "quiet-node",
                "mac": "AA:BB:CC:DD:EE:02",
                "name": "Just Added",
                "node_type": "plant",
                "room_id": "",
                "online": false,
                "last_seen": null,
                "latest": null
            }
        ]
        """.data(using: .utf8)!

        let plants = try JSONDecoder.carlHub().decode([Plant].self, from: json)

        XCTAssertEqual(plants.count, 2, "One incomplete node must not fail the whole list.")
        XCTAssertEqual(plants[0].latest.soilPct, 42.0)
        XCTAssertEqual(plants[1].status(), .offline)
    }
}
