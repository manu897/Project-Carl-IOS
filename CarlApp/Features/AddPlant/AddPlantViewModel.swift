import Foundation
import Observation
import UIKit

@Observable
@MainActor
final class AddPlantViewModel {
    // Form state
    var name: String = ""
    var mac: String = ""
    var keyHex: String = ""
    var photo: UIImage?

    // Flow state
    var isSubmitting = false
    var errorMessage: String?
    /// Set to the new node id on success — used to persist the photo
    /// after `POST /api/nodes` returns the canonical id from the hub.
    private(set) var createdNodeId: String?

    private let repository: any PlantRepository
    private let photoStore: PhotoStore

    init(repository: any PlantRepository, photoStore: PhotoStore = .shared) {
        self.repository = repository
        self.photoStore = photoStore
    }

    var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && (try? CarlNodeURL.from(mac: mac, key: keyHex)) != nil
            && !isSubmitting
    }

    /// Applies a scanned `carl://node?...` payload to the form fields.
    /// Returns `nil` if it parses cleanly, otherwise an error message.
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
            let plant = try await repository.add(mac: node.mac, keyHex: node.keyHex, name: trimmedName)
            createdNodeId = plant.id
            if let photo {
                // Persist locally for MVP. When Norman's photo endpoint exists
                // this is where the upload (and an offline retry queue) goes.
                try? photoStore.save(photo, for: plant.id)
            }
            return true
        } catch {
            errorMessage = friendlyMessage(for: error)
            return false
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
