import Foundation
import Observation

@Observable
@MainActor
final class HubSetupViewModel {
    enum Stage: Equatable {
        case instructions
        case form
        case submitting
        case success
        case failed(String)
    }

    var stage: Stage = .instructions
    var ssid: String = ""
    var password: String = ""

    /// The hub serves its SoftAP at 192.168.4.1 by convention (ESP-IDF default).
    /// The captive-portal `POST /api/setup/wifi` endpoint accepts JSON
    /// `{ssid, psk}` and the hub reboots into station mode on success.
    private static let setupBaseURL = URL(string: "http://192.168.4.1")!

    var canSubmit: Bool {
        !ssid.trimmingCharacters(in: .whitespaces).isEmpty && stage != .submitting
    }

    func startForm() { stage = .form }

    func submit() async {
        stage = .submitting
        let client = HTTPHubClient(baseURL: Self.setupBaseURL)
        do {
            try await client.setupWifi(WifiCreds(ssid: ssid, psk: password))
            stage = .success
        } catch {
            stage = .failed(friendlyMessage(for: error))
        }
    }

    func reset() {
        stage = .instructions
        ssid = ""
        password = ""
    }

    private func friendlyMessage(for error: Error) -> String {
        let nsError = error as NSError
        switch nsError.code {
        case NSURLErrorCannotConnectToHost,
             NSURLErrorCannotFindHost,
             NSURLErrorNotConnectedToInternet,
             NSURLErrorTimedOut:
            return "Couldn't reach the hub at 192.168.4.1. Make sure your phone is connected to the Carl-Hub-Setup Wi-Fi network, then try again."
        default:
            if let hubError = error as? HubError { return hubError.message }
            return nsError.localizedDescription
        }
    }
}
