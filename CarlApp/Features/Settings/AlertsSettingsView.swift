import SwiftUI
import UserNotifications

struct AlertsSettingsView: View {
    let plants: [Plant]

    @AppStorage(SettingsKeys.alertsEnabled) private var alertsEnabled: Bool = false
    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var mutedSnapshot: Set<String> = []
    @State private var history: [AlertEngine.FiredEvent] = []

    var body: some View {
        Form {
            Section {
                Toggle("Send alerts", isOn: $alertsEnabled)
                    .onChange(of: alertsEnabled) { _, on in
                        Task { await handleToggle(on: on) }
                    }
                if alertsEnabled, authStatus == .denied {
                    permissionDeniedRow
                }
            } header: {
                Text("Notifications")
            } footer: {
                Text(footerText)
            }

            if !plants.isEmpty {
                Section {
                    ForEach(plants) { plant in
                        Toggle(isOn: bindingForMute(plant.id)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(plant.name)
                                Text("Send alerts for this plant")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Per-plant")
                } footer: {
                    Text("Turn a plant off to silence its alerts. The plant still appears in My Plants.")
                }
            }

            if !history.isEmpty {
                Section("Recent") {
                    ForEach(history, id: \.self) { event in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.kind.title)
                                    .font(.subheadline)
                                Text(plantName(event.plantId))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(event.at.formatted(.relative(presentation: .named)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Alerts")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refreshState() }
    }

    // MARK: - Subviews

    private var permissionDeniedRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Notifications are off in iOS Settings", systemImage: "bell.slash")
                .foregroundStyle(.orange)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Carl in iOS Settings to allow notifications")
                    .font(.caption)
            }
        }
    }

    private var footerText: String {
        if !alertsEnabled {
            return "Carl will let you know when a plant needs water, a sensor's battery is low, or a node hasn't reported recently."
        }
        switch authStatus {
        case .authorized, .provisional, .ephemeral:
            return "Each plant gets at most one notification per condition every 6 hours."
        case .denied:
            return "iOS is blocking notifications for Carl. Tap the link above to allow them."
        case .notDetermined:
            return "Tap Send alerts again to grant notification permission."
        @unknown default:
            return ""
        }
    }

    // MARK: - State

    private func bindingForMute(_ plantId: String) -> Binding<Bool> {
        Binding(
            get: { !mutedSnapshot.contains(plantId) },   // toggle ON = not muted
            set: { isOn in
                AlertEngine.shared.setMuted(!isOn, for: plantId)
                if isOn { mutedSnapshot.remove(plantId) } else { mutedSnapshot.insert(plantId) }
            }
        )
    }

    private func plantName(_ id: String) -> String {
        plants.first(where: { $0.id == id })?.name ?? id
    }

    private func refreshState() async {
        authStatus = await AlertEngine.shared.authorizationStatus()
        mutedSnapshot = Set(plants.filter { AlertEngine.shared.isMuted($0.id) }.map(\.id))
        history = AlertEngine.shared.recentHistory()
    }

    private func handleToggle(on: Bool) async {
        if on {
            let granted = await AlertEngine.shared.ensurePermission()
            authStatus = await AlertEngine.shared.authorizationStatus()
            if !granted {
                alertsEnabled = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        AlertsSettingsView(plants: [])
    }
}
