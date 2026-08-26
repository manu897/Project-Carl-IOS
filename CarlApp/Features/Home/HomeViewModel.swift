import Foundation
import Observation

@Observable
@MainActor
final class HomeViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    /// Data older than this with no successful refresh since is "no longer
    /// trustworthy" — the UI switches from a quiet "Updated Xh ago" badge to
    /// an explicit warning instead of silently showing very old numbers.
    static let staleThreshold: TimeInterval = 24 * 3600

    private(set) var state: LoadState = .idle
    private(set) var plants: [Plant] = []
    /// When `plants` was last populated from a *successful* fetch — live or
    /// cached. `nil` only before the very first load ever completes.
    private(set) var lastUpdated: Date?

    var isStale: Bool {
        guard let lastUpdated else { return false }
        return Date.now.timeIntervalSince(lastUpdated) > Self.staleThreshold
    }

    let repository: any PlantRepository
    private let cacheStore: PlantCacheStore
    /// Mock fixtures must never touch the real-data cache — otherwise
    /// switching off "Use mock data" while offline could show fake plants
    /// labeled as legitimately cached, or a real fetch while previewing mock
    /// data could silently overwrite the user's actual last-known readings.
    private let cachingEnabled: Bool
    nonisolated(unsafe) private var streamTask: Task<Void, Never>?

    init(repository: any PlantRepository, cacheStore: PlantCacheStore = .shared, cachingEnabled: Bool = true) {
        self.repository = repository
        self.cacheStore = cacheStore
        self.cachingEnabled = cachingEnabled
    }

    func load() async {
        // Show the last-known list instantly, before any network round-trip —
        // this is what turns a cold launch from a blank spinner into
        // immediately-useful (if possibly stale) data.
        if cachingEnabled, let snapshot = cacheStore.load(), !snapshot.plants.isEmpty {
            plants = snapshot.plants
            lastUpdated = snapshot.fetchedAt
            state = .loaded
        } else {
            state = .loading
        }
        await fetchFresh()
    }

    func refresh() async {
        await fetchFresh()
    }

    deinit {
        streamTask?.cancel()
    }

    private func fetchFresh() async {
        do {
            let fresh = try await repository.plants()
            plants = fresh
            lastUpdated = .now
            state = .loaded
            if cachingEnabled {
                cacheStore.save(fresh, fetchedAt: .now)
            }
            await AlertEngine.shared.evaluate(plants)
            startLiveUpdates()
        } catch {
            // If we already have something on screen (cache or a previous
            // live fetch this session), keep showing it rather than
            // replacing it with a failure screen — `isStale` is how the UI
            // surfaces that the fetch didn't succeed, not a blank error
            // state wiping out data the user could still act on.
            if plants.isEmpty {
                state = .failed(error.localizedDescription)
            }
        }
    }

    private func startLiveUpdates() {
        streamTask?.cancel()
        let stream = repository.liveUpdates()
        streamTask = Task { [weak self] in
            do {
                for try await frame in stream {
                    self?.apply(frame)
                }
            } catch {
                // Stream broke (hub gone, network change). Repo will reconnect
                // on the next manual refresh; we just exit quietly here.
            }
        }
    }

    private func apply(_ frame: StreamFrame) {
        guard let idx = plants.firstIndex(where: { $0.id == frame.nodeId }) else { return }
        switch frame.type {
        case .reading:
            if let reading = frame.payload {
                plants[idx].latest = reading
                plants[idx].lastSeen = reading.timestamp
                if let battery = reading.batteryPct {
                    plants[idx].batteryPct = battery
                }
                plants[idx].online = true
                lastUpdated = .now
            }
        case .online:
            plants[idx].online = true
        case .offline:
            plants[idx].online = false
        }
    }
}
