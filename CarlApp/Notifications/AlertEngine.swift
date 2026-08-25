import Foundation
import UserNotifications

/// Evaluates `Plant` health and posts local notifications. Rate-limits per
/// `(plant, alert-kind)` so the user gets one nudge per condition per window,
/// not a notification every refresh.
@MainActor
final class AlertEngine {
    enum Kind: String, CaseIterable, Codable {
        case dry, lowBattery, offline

        var title: String {
            switch self {
            case .dry:        return "Time to water"
            case .lowBattery: return "Sensor battery low"
            case .offline:    return "Plant offline"
            }
        }

        func body(for plant: Plant) -> String {
            switch self {
            case .dry:        return "\(plant.name) needs water."
            case .lowBattery: return "The sensor on \(plant.name) needs a fresh battery."
            case .offline:    return "\(plant.name) hasn't reported recently — check the sensor."
            }
        }
    }

    /// Re-fire the same alert at most this often per `(plant, kind)`.
    static let rateLimit: TimeInterval = 6 * 3600   // 6 hours

    static let shared = AlertEngine()

    private let defaults: UserDefaults
    private let notificationCenter: UNUserNotificationCenter
    private let storageKey = "AlertEngine.lastFired"

    init(defaults: UserDefaults = .standard,
         notificationCenter: UNUserNotificationCenter = .current()) {
        self.defaults = defaults
        self.notificationCenter = notificationCenter
    }

    // MARK: - Public API

    /// Are alerts globally enabled? Default: false (off until the user opts in).
    var globallyEnabled: Bool {
        get { defaults.bool(forKey: SettingsKeys.alertsEnabled) }
        set { defaults.set(newValue, forKey: SettingsKeys.alertsEnabled) }
    }

    /// Run evaluation across the current snapshot. Posts notifications for
    /// any (plant, kind) past its rate-limit window.
    func evaluate(_ plants: [Plant], now: Date = .now) async {
        guard globallyEnabled else { return }
        guard await ensurePermission() else { return }

        for plant in plants where !isMuted(plant.id) {
            guard let kind = matchingKind(for: plant) else { continue }
            if shouldFire(plantId: plant.id, kind: kind, now: now) {
                await post(plant: plant, kind: kind)
                recordFired(plantId: plant.id, kind: kind, at: now)
            }
        }
    }

    // MARK: - Per-plant mute

    func isMuted(_ plantId: String) -> Bool {
        Set(defaults.stringArray(forKey: SettingsKeys.alertsMuted) ?? []).contains(plantId)
    }

    func setMuted(_ muted: Bool, for plantId: String) {
        var current = Set(defaults.stringArray(forKey: SettingsKeys.alertsMuted) ?? [])
        if muted { current.insert(plantId) } else { current.remove(plantId) }
        defaults.set(Array(current), forKey: SettingsKeys.alertsMuted)
    }

    // MARK: - Last-fired log (read-only access for the UI)

    struct FiredEvent: Codable, Hashable {
        let plantId: String
        let kind: Kind
        let at: Date
    }

    func recentHistory(limit: Int = 20) -> [FiredEvent] {
        loadLastFired()
            .map { FiredEvent(plantId: $0.key.plantId, kind: $0.key.kind, at: $0.value) }
            .sorted { $0.at > $1.at }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Permission

    /// Returns true if the system already authorises alerts or the user grants
    /// them just now. Returns false on deny.
    @discardableResult
    func ensurePermission() async -> Bool {
        let settings = await notificationCenter.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        @unknown default:
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await notificationCenter.notificationSettings().authorizationStatus
    }

    // MARK: - Private

    private func matchingKind(for plant: Plant) -> Kind? {
        switch plant.status() {
        case .dry:        return .dry
        case .lowBattery: return .lowBattery
        case .offline:    return .offline
        case .ok:         return nil
        }
    }

    private struct Key: Hashable, Codable {
        let plantId: String
        let kind: Kind
    }

    private func loadLastFired() -> [Key: Date] {
        guard let raw = defaults.data(forKey: storageKey),
              let map = try? JSONDecoder().decode([Key: Date].self, from: raw) else {
            return [:]
        }
        return map
    }

    private func saveLastFired(_ map: [Key: Date]) {
        if let data = try? JSONEncoder().encode(map) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private func shouldFire(plantId: String, kind: Kind, now: Date) -> Bool {
        let key = Key(plantId: plantId, kind: kind)
        guard let lastAt = loadLastFired()[key] else { return true }
        return now.timeIntervalSince(lastAt) >= Self.rateLimit
    }

    private func recordFired(plantId: String, kind: Kind, at: Date) {
        var map = loadLastFired()
        map[Key(plantId: plantId, kind: kind)] = at
        saveLastFired(map)
    }

    private func post(plant: Plant, kind: Kind) async {
        let content = UNMutableNotificationContent()
        content.title = kind.title
        content.body = kind.body(for: plant)
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "carl.\(plant.id).\(kind.rawValue)",
            content: content,
            trigger: nil
        )
        try? await notificationCenter.add(request)
    }
}
