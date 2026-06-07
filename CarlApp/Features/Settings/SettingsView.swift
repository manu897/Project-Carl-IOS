import SwiftUI

struct SettingsView: View {
    @AppStorage(SettingsKeys.useMockHub) private var useMockHub: Bool = true
    @Environment(\.dismiss) private var dismiss

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
