import Foundation
import Network

@MainActor
final class HubDiscovery: ObservableObject {
    @Published private(set) var hubURL: URL?
    @Published private(set) var isSearching = false

    private var browser: NWBrowser?

    func start() {
        guard browser == nil else { return }
        isSearching = true

        let parameters = NWParameters()
        parameters.includePeerToPeer = false

        let browser = NWBrowser(
            for: .bonjour(type: "_carl-hub._tcp", domain: nil),
            using: parameters
        )

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self else { return }
            Task { @MainActor in
                guard let result = results.first else {
                    self.hubURL = nil
                    return
                }
                self.resolve(result)
            }
        }

        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                if case .failed = state {
                    self?.hubURL = nil
                    self?.isSearching = false
                }
            }
        }

        browser.start(queue: .main)
        self.browser = browser
    }

    func stop() {
        browser?.cancel()
        browser = nil
        isSearching = false
    }

    private func resolve(_ result: NWBrowser.Result) {
        guard case let .service(name, _, _, _) = result.endpoint else { return }
        // Hub publishes itself at <hub_id>._carl-hub._tcp.local. — but we always
        // reach it at carl-hub.local on the LAN, so we hand back that URL rather
        // than going through NWConnection resolution. (Multi-hub support: TODO.)
        _ = name
        hubURL = URL(string: "http://carl-hub.local")
    }
}
