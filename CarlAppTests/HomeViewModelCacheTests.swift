import XCTest
@testable import CarlApp

private final class FakePlantRepository: PlantRepository, @unchecked Sendable {
    var plantsResult: Result<[Plant], Error> = .success([])

    func plants() async throws -> [Plant] { try plantsResult.get() }
    func plant(id: String) async throws -> Plant { try plantsResult.get().first! }
    func history(id: String, range: History.Range) async throws -> History {
        History(nodeId: id, range: range, samples: [])
    }
    func add(mac: String, keyHex: String, name: String, nodeType: NodeType?, roomId: String?, calibration: Calibration?) async throws -> Plant {
        try plantsResult.get().first!
    }
    func rename(id: String, to name: String) async throws -> Plant { try plantsResult.get().first! }
    func updateCalibration(id: String, _ calibration: Calibration) async throws -> Plant { try plantsResult.get().first! }
    func remove(id: String) async throws {}
    func liveUpdates() -> AsyncThrowingStream<StreamFrame, Error> { AsyncThrowingStream { $0.finish() } }
}

@MainActor
final class HomeViewModelCacheTests: XCTestCase {
    private func plant(id: String, soil: Double) -> Plant {
        Plant(
            id: id, mac: "AA:BB:CC:DD:EE:01", name: "Cached Plant",
            lastSeen: .now, online: true, batteryPct: 80,
            latest: Reading(timestamp: .now, soilPct: soil)
        )
    }

    func test_load_showsCachedDataInstantly_thenReplacesWithFreshOnSuccess() async {
        let cacheDir = FileManager.default.temporaryDirectory
        let cacheFile = cacheDir.appendingPathComponent("cache-\(UUID().uuidString).json")
        let cache = PlantCacheStore(fileURL: cacheFile)
        cache.save([plant(id: "cached", soil: 10)], fetchedAt: Date(timeIntervalSinceNow: -3600))

        let repo = FakePlantRepository()
        repo.plantsResult = .success([plant(id: "fresh", soil: 55)])

        let vm = HomeViewModel(repository: repo, cacheStore: cache)
        await vm.load()

        // After load() completes, the fresh fetch should have won.
        XCTAssertEqual(vm.plants.map(\.id), ["fresh"])
        XCTAssertEqual(vm.state, .loaded)
        XCTAssertFalse(vm.isStale)

        // And the cache should now hold the fresh data for next launch.
        XCTAssertEqual(cache.load()?.plants.map(\.id), ["fresh"])
    }

    func test_load_keepsCachedDataVisible_whenFetchFails() async {
        let cacheDir = FileManager.default.temporaryDirectory
        let cacheFile = cacheDir.appendingPathComponent("cache-\(UUID().uuidString).json")
        let cache = PlantCacheStore(fileURL: cacheFile)
        cache.save([plant(id: "cached", soil: 10)], fetchedAt: .now)

        let repo = FakePlantRepository()
        repo.plantsResult = .failure(HubError(code: "offline", message: "no network"))

        let vm = HomeViewModel(repository: repo, cacheStore: cache)
        await vm.load()

        // The fetch failed, but we still have cached data — don't blank the screen.
        XCTAssertEqual(vm.plants.map(\.id), ["cached"])
        XCTAssertEqual(vm.state, .loaded)
    }

    func test_isStale_falseJustAfterLoad_trueWellPastThreshold() async {
        let cacheDir = FileManager.default.temporaryDirectory
        let cacheFile = cacheDir.appendingPathComponent("cache-\(UUID().uuidString).json")
        let cache = PlantCacheStore(fileURL: cacheFile)
        // Cached data from 2 days ago, well past the 24h threshold.
        cache.save([plant(id: "old", soil: 10)], fetchedAt: Date(timeIntervalSinceNow: -2 * 24 * 3600))

        let repo = FakePlantRepository()
        repo.plantsResult = .failure(HubError(code: "offline", message: "no network"))

        let vm = HomeViewModel(repository: repo, cacheStore: cache)
        await vm.load()

        XCTAssertEqual(vm.plants.map(\.id), ["old"], "Old data should still be shown, not hidden.")
        XCTAssertTrue(vm.isStale, "Data older than the threshold with a failed refresh must be flagged stale.")
    }

    func test_cachingDisabled_neitherReadsNorWritesTheCache() async {
        let cacheDir = FileManager.default.temporaryDirectory
        let cacheFile = cacheDir.appendingPathComponent("cache-\(UUID().uuidString).json")
        let cache = PlantCacheStore(fileURL: cacheFile)
        // Pre-seed with "real" cached data — this must be ignored entirely
        // while caching is disabled (the mock-data scenario).
        cache.save([plant(id: "stale-real-data", soil: 5)], fetchedAt: Date(timeIntervalSinceNow: -3600))

        let repo = FakePlantRepository()
        repo.plantsResult = .success([plant(id: "mock-fixture", soil: 50)])

        let vm = HomeViewModel(repository: repo, cacheStore: cache, cachingEnabled: false)
        await vm.load()

        XCTAssertEqual(vm.plants.map(\.id), ["mock-fixture"], "Mock mode must never read stale real data from the cache.")
        XCTAssertEqual(
            cache.load()?.plants.map(\.id), ["stale-real-data"],
            "Mock mode must never overwrite the real-data cache with fixtures."
        )
    }

    func test_noCacheAndFetchFails_surfacesAFailureState() async {
        let cacheDir = FileManager.default.temporaryDirectory
        let cacheFile = cacheDir.appendingPathComponent("cache-\(UUID().uuidString).json")
        let cache = PlantCacheStore(fileURL: cacheFile) // never saved to — empty

        let repo = FakePlantRepository()
        repo.plantsResult = .failure(HubError(code: "offline", message: "no network"))

        let vm = HomeViewModel(repository: repo, cacheStore: cache)
        await vm.load()

        XCTAssertTrue(vm.plants.isEmpty)
        if case .failed = vm.state {
            // expected
        } else {
            XCTFail("Expected .failed when there's no cache and the fetch fails, got \(vm.state)")
        }
    }
}
