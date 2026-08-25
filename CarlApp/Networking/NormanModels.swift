import Foundation

struct NormanTokenResponse: Codable, Sendable {
    let accessToken: String
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
    }
}

struct NormanErrorBody: Codable, Sendable {
    let detail: String?
}
