import Foundation
import Observation

/// Handles account creation and sign-in against Norman's `/v1/auth/*`
/// endpoints. Separate from `NormanClient` (which only reads plant data)
/// since auth happens before a token exists.
@Observable
@MainActor
final class NormanAuthManager {
    static let shared = NormanAuthManager()

    private(set) var isSignedIn: Bool = NormanSession.isSignedIn
    private(set) var email: String? = NormanSession.email
    var isWorking = false
    var errorMessage: String?

    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = AppEnvironment.normanBaseURL, session: URLSession = NormanClient.defaultSession()) {
        self.baseURL = baseURL
        self.session = session
    }

    func register(email: String, password: String) async -> Bool {
        await authenticate(path: "/v1/auth/register", body: try? JSONEncoder().encode([
            "email": email, "password": password,
        ]), contentType: "application/json", email: email)
    }

    func login(email: String, password: String) async -> Bool {
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "username", value: email),
            URLQueryItem(name: "password", value: password),
        ]
        let formBody = components.percentEncodedQuery?.data(using: .utf8)
        return await authenticate(
            path: "/v1/auth/login",
            body: formBody,
            contentType: "application/x-www-form-urlencoded",
            email: email
        )
    }

    func signOut() {
        NormanSession.clear()
        isSignedIn = false
        email = nil
    }

    // MARK: - Private

    private func authenticate(path: String, body: Data?, contentType: String, email: String) async -> Bool {
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }

        guard let body else {
            errorMessage = "Couldn't prepare that request."
            return false
        }

        var request = URLRequest(url: baseURL.appendingCarlPath(path))
        request.httpMethod = "POST"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = body
        request = NormanClient.disablingHTTP3(request)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                errorMessage = "Couldn't reach the cloud service."
                return false
            }
            guard (200..<300).contains(http.statusCode) else {
                errorMessage = friendlyMessage(status: http.statusCode, data: data)
                return false
            }
            let token = try JSONDecoder().decode(NormanTokenResponse.self, from: data)
            NormanSession.save(token: token.accessToken, email: email)
            isSignedIn = true
            self.email = email
            return true
        } catch {
            errorMessage = "Couldn't reach the cloud service. Check your internet connection."
            return false
        }
    }

    private func friendlyMessage(status: Int, data: Data) -> String {
        if let body = try? JSONDecoder().decode(NormanErrorBody.self, from: data), let detail = body.detail {
            return detail
        }
        switch status {
        case 401: return "Incorrect email or password."
        case 409: return "An account with that email already exists — try signing in instead."
        default: return "Something went wrong (\(status)). Try again."
        }
    }
}
