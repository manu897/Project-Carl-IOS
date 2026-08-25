import Foundation
import Observation
import UIKit

@Observable
@MainActor
final class AddPlantViewModel {
    enum ClassificationState: Sendable {
        case idle
        case classifying
        case done([PlantClassifier.Result])
        case failed
    }

    // Form state
    var name: String = ""
    var mac: String = ""
    var keyHex: String = ""
    var photo: UIImage? {
        didSet { classifyPhoto() }
    }

    // Classification state
    private(set) var classificationState: ClassificationState = .idle
    var selectedSpecies: SpeciesInfo?

    // Flow state
    var isSubmitting = false
    var errorMessage: String?
    private(set) var createdNodeId: String?

    private let repository: any PlantRepository
    private let photoStore: PhotoStore
    private let speciesStore: SpeciesStore

    init(repository: any PlantRepository, photoStore: PhotoStore = .shared, speciesStore: SpeciesStore = .shared) {
        self.repository = repository
        self.photoStore = photoStore
        self.speciesStore = speciesStore
    }

    var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && (try? CarlNodeURL.from(mac: mac, key: keyHex)) != nil
            && !isSubmitting
    }

    @discardableResult
    func applyScanned(_ raw: String) -> String? {
        do {
            let parsed = try CarlNodeURL.parse(raw)
            mac = parsed.mac
            keyHex = parsed.keyHex
            errorMessage = nil
            return nil
        } catch {
            let msg = error.localizedDescription
            errorMessage = msg
            return msg
        }
    }

    func selectSpecies(_ result: PlantClassifier.Result) {
        let info = SpeciesInfo(
            identifier: result.identifier,
            commonName: result.commonName,
            scientificName: SpeciesCatalog.scientificNames[result.identifier],
            confidence: result.confidence
        )
        selectedSpecies = info
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            name = result.commonName
        }
    }

    func submit() async -> Bool {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        let node: CarlNodeURL
        do {
            node = try CarlNodeURL.from(mac: mac, key: keyHex)
        } catch {
            errorMessage = error.localizedDescription
            return false
        }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        do {
            var calibration: Calibration?
            if let species = selectedSpecies,
               let speciesDefaults = SpeciesCatalog.defaults(for: species.identifier) {
                calibration = speciesDefaults.calibration
            }

            let plant = try await repository.add(
                mac: node.mac, keyHex: node.keyHex, name: trimmedName,
                nodeType: nil, roomId: nil, calibration: calibration
            )
            createdNodeId = plant.id
            if let photo {
                try? photoStore.save(photo, for: plant.id)
            }
            if let species = selectedSpecies {
                try? speciesStore.save(species, for: plant.id)
            }
            return true
        } catch {
            errorMessage = friendlyMessage(for: error)
            return false
        }
    }

    // MARK: - Private

    private func classifyPhoto() {
        guard let image = photo else {
            classificationState = .idle
            return
        }
        classificationState = .classifying
        Task {
            do {
                let results = try await PlantClassifier.shared.classify(image)
                classificationState = results.isEmpty ? .idle : .done(results)
                if let top = results.first, name.trimmingCharacters(in: .whitespaces).isEmpty {
                    selectSpecies(top)
                }
            } catch {
                classificationState = .failed
            }
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        if let hubError = error as? HubError {
            switch hubError.code {
            case "conflict", "http_409":
                return "This sensor is already added — check My Plants."
            case let code where code.hasPrefix("http_5"):
                return "The hub had a problem registering this node. Try again in a moment."
            default:
                return hubError.message
            }
        }
        return error.localizedDescription
    }
}
