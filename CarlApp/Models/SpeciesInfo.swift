import Foundation

struct SpeciesInfo: Codable, Hashable, Sendable {
    let identifier: String
    let commonName: String
    let scientificName: String?
    let confidence: Double
}
