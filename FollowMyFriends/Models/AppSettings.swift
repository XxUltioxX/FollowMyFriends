import Foundation

struct AppSettings: Codable, Sendable {
    // MQTT
    var mqttHost: String = "192.168.1.100"
    var mqttPort: Int = 1883
    var mqttUsername: String = ""
    var mqttTopicPrefix: String = "homeassistant/device_tracker/"

    // Polling
    var pollIntervalMin: Int = 45
    var pollIntervalMax: Int = 600
    var randomizeInterval: Bool = true
    var findMyWaitSeconds: Int = 15
    var manualRefreshThrottleSeconds: Int = 60

    // Night Mode
    var nightModeEnabled: Bool = false
    var nightModeStart: String = "23:00"   // HH:mm
    var nightModeEnd: String = "07:00"     // HH:mm

    // Key File
    var keyFilePath: String = ""

    // User-selected FindMy database path (bypasses TCC via NSOpenPanel user intent)
    var customDBPath: String = ""
    var dbBookmarkData: Data?

    // Application
    var launchAtStartup: Bool = false
    var showInDock: Bool = true

    // Tracked People
    var trackedPeople: [TrackedPerson] = []

    // MARK: - Persistence

    static var settingsURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("FollowMyFriends")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("settings.json")
    }

    static func load() -> AppSettings {
        guard let data = try? Data(contentsOf: settingsURL),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            var defaults = AppSettings()
            defaults.keyFilePath = FindMyDecryptor.autoDetectKeyPath() ?? ""
            return defaults
        }
        return settings
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(self) {
            try? data.write(to: AppSettings.settingsURL, options: .atomic)
        }
    }
}
