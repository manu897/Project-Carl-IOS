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

    private(set) var state: LoadState = .idle
    private(set) var plants: [Plant] = []

    private let repository: any PlantRepository
    nonisolated(unsafe) private var streamTask: Task<Void, Never>?

    init(repository: any PlantRepository) {
        self.repository = repository
    }

    func load() async {
        state = .loading
        do {
            plants = try await repository.plants()
            state = .loaded
            startLiveUpdates()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func refresh() async {
        do {
            plants = try await repository.plants()
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    deinit {
        streamTask?.cancel()
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
            }
        case .online:
            plants[idx].online = true
        case .offline:
            plants[idx].online = false
        }
    }
}
