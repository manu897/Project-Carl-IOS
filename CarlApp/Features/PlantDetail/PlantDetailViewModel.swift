import Foundation
import Observation

@Observable
@MainActor
final class PlantDetailViewModel {
    let plant: Plant
    var range: History.Range = .h24
    private(set) var samples: [Reading] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let repository: any PlantRepository

    init(plant: Plant, repository: any PlantRepository) {
        self.plant = plant
        self.repository = repository
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let history = try await repository.history(id: plant.id, range: range)
            samples = history.samples
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
