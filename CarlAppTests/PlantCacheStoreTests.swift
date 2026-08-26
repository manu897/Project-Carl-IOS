import XCTest
@testable import CarlApp

final class PlantCacheStoreTests: XCTestCase {
    private func makeStore() -> PlantCacheStore {
        let dir = FileManager.default.temporaryDirectory
        let file = dir.appendingPathComponent("plants-cache-test-\(UUID().uuidString).json")
        return PlantCacheStore(fileURL: file)
    }

    private func samplePlant(id: String = "p1") -> Plant {
        Plant(
            id: id, mac: "AA:BB:CC:DD:EE:01", name: "Test Plant",
            lastSeen: .now, online: true, batteryPct: 80,
            latest: Reading(timestamp: .now, soilPct: 40)
        )
    }

    func test_returnsNil_whenNothingSavedYet() {
        XCTAssertNil(makeStore().load())
    }

    func test_savedSnapshot_roundTripsExactly() {
        let store = makeStore()
        let plants = [samplePlant(id: "a"), samplePlant(id: "b")]
        let fetchedAt = Date(timeIntervalSince1970: 1_700_000_000)

        store.save(plants, fetchedAt: fetchedAt)
        let loaded = store.load()

        XCTAssertEqual(loaded?.plants.map(\.id), ["a", "b"])
        XCTAssertEqual(loaded?.fetchedAt.timeIntervalSince1970 ?? 0, fetchedAt.timeIntervalSince1970, accuracy: 1)
    }

    func test_clear_removesTheSnapshot() {
        let store = makeStore()
        store.save([samplePlant()], fetchedAt: .now)
        XCTAssertNotNil(store.load())

        store.clear()
        XCTAssertNil(store.load())
    }
}
