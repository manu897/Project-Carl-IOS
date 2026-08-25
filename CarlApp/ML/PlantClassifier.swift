import UIKit
import Vision
import CoreML

actor PlantClassifier {
    static let shared = PlantClassifier()

    struct Result: Sendable {
        let identifier: String
        let commonName: String
        let confidence: Double
    }

    private let minimumConfidence: Float = 0.15

    func classify(_ image: UIImage) async throws -> [Result] {
        guard let cgImage = image.cgImage else { return [] }

        if let coreMLResults = try? await classifyWithCoreML(cgImage) {
            return coreMLResults
        }

        return try await classifyWithBuiltIn(cgImage)
    }

    private func classifyWithCoreML(_ cgImage: CGImage) async throws -> [Result] {
        guard let modelURL = Bundle.main.url(forResource: "PlantID", withExtension: "mlmodelc")
                ?? Bundle.main.url(forResource: "PlantID", withExtension: "mlmodel") else {
            throw ClassifierError.noCustomModel
        }
        let compiledURL: URL
        if modelURL.pathExtension == "mlmodelc" {
            compiledURL = modelURL
        } else {
            compiledURL = try await MLModel.compileModel(at: modelURL)
        }
        let model = try MLModel(contentsOf: compiledURL)
        let vnModel = try VNCoreMLModel(for: model)

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNCoreMLRequest(model: vnModel) { [minimumConfidence] request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNClassificationObservation]) ?? []
                let results = observations
                    .filter { $0.confidence >= minimumConfidence }
                    .prefix(3)
                    .map { obs in
                        let id = obs.identifier
                        let name = SpeciesCatalog.commonNames[id] ?? id.replacingOccurrences(of: "_", with: " ").capitalized
                        return Result(identifier: id, commonName: name, confidence: Double(obs.confidence))
                    }
                continuation.resume(returning: Array(results))
            }
            request.imageCropAndScaleOption = .centerCrop
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func classifyWithBuiltIn(_ cgImage: CGImage) async throws -> [Result] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNClassifyImageRequest { [minimumConfidence] request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNClassificationObservation]) ?? []
                let mapped = observations
                    .filter { $0.confidence >= minimumConfidence }
                    .compactMap { obs -> Result? in
                        guard let mapped = Self.builtInMapping[obs.identifier] else { return nil }
                        return Result(identifier: mapped, commonName: SpeciesCatalog.commonNames[mapped] ?? obs.identifier.capitalized, confidence: Double(obs.confidence))
                    }
                    .prefix(3)
                continuation.resume(returning: Array(mapped))
            }
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private static let builtInMapping: [String: String] = [
        "daisy": "bellis_perennis",
        "sunflower": "helianthus_annuus",
        "aloe": "aloe_vera",
        "cactus": "crassula_ovata",
        "succulent": "crassula_ovata",
        "fern": "nephrolepis_exaltata",
        "ivy": "hedera_helix",
        "pot plant": "epipremnum_aureum",
        "flowerpot": "epipremnum_aureum",
    ]

    enum ClassifierError: Error {
        case noCustomModel
    }
}
