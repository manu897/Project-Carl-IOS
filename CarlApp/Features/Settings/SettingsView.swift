import SwiftUI

struct SettingsView: View {
    var plants: [Plant] = []

    @AppStorage(SettingsKeys.useMockHub) private var useMockHub: Bool = true
    @AppStorage(SettingsKeys.alertsEnabled) private var alertsEnabled: Bool = false
    @Environment(\.dismiss) private var dismiss
    @State private var showingHubSetup = false
    @State private var showingAccount = false
    private let normanAuth = NormanAuthManager.shared

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Use mock data", isOn: $useMockHub)
                } header: {
                    Text("Data source")
                } footer: {
                    Text(useMockHub
                         ? "Showing built-in sample plants. Turn off to connect to your Carl hub at carl-hub.local on this Wi-Fi."
                         : "Connecting to your Carl hub at \(AppEnvironment.defaultHubURL.host ?? "carl-hub.local") over the local network.")
                }

                Section {
                    Button {
                        showingHubSetup = true
                    } label: {
                        Label("Set up hub Wi-Fi", systemImage: "wifi")
                    }
                } header: {
                    Text("Hub")
                } footer: {
                    Text("Use this when adding a brand-new Carl hub that needs to join your home Wi-Fi for the first time.")
                }

                Section {
                    Button {
                        showingAccount = true
                    } label: {
                        HStack {
                            Label("Cloud account", systemImage: "cloud")
                            Spacer()
                            Text(normanAuth.isSignedIn ? (normanAuth.email ?? "Signed in") : "Signed out")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Away from home")
                } footer: {
                    Text("Sign in to keep seeing your plants when you're off your home Wi-Fi. Optional — the app works LAN-only without it.")
                }

                Section {
                    NavigationLink {
                        AlertsSettingsView(plants: plants)
                    } label: {
                        HStack {
                            Label("Alerts", systemImage: "bell.badge")
                            Spacer()
                            Text(alertsEnabled ? "On" : "Off")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Get notified when a plant needs water, a sensor battery is low, or a node hasn't reported.")
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.versionString)
                    LabeledContent("Build", value: Bundle.main.buildString)
                    Link(destination: URL(string: "https://github.com/manu897/Project-Carl-IOS")!) {
                        Label("Source on GitHub", systemImage: "link")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingHubSetup) {
                HubSetupView()
            }
            .sheet(isPresented: $showingAccount) {
                NormanAccountView(auth: normanAuth)
            }
        }
    }
}

private extension Bundle {
    var versionString: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "—"
    }
    var buildString: String {
        (infoDictionary?["CFBundleVersion"] as? String) ?? "—"
    }
}

#Preview {
    SettingsView()
}
