import Foundation
import CocoaMQTT

enum MQTTConnectionState: Sendable {
    case connected
    case disconnected
    case reconnecting
}

@MainActor
final class MQTTService: NSObject, ObservableObject {
    @Published private(set) var connectionState: MQTTConnectionState = .disconnected

    var onLog: (@Sendable (LogEntry.Level, String) -> Void)?
    var onConnected: (@Sendable () -> Void)?

    private var client: CocoaMQTT?
    private var settings: AppSettings
    private var reconnectTask: Task<Void, Never>?
    private var reconnectAttempts = 0

    init(settings: AppSettings) {
        self.settings = settings
    }

    func configure(with settings: AppSettings) {
        self.settings = settings
    }

    // MARK: - Connection

    func connect() {
        disconnect()

        let clientId = "FollowMyFriends-\(UUID().uuidString.prefix(8))"
        let mqtt = CocoaMQTT(
            clientID: clientId,
            host: settings.mqttHost,
            port: UInt16(settings.mqttPort)
        )
        if !settings.mqttUsername.isEmpty {
            mqtt.username = settings.mqttUsername
            // Password is read from Keychain at connection time
            if let pass = KeychainHelper.readPassword() {
                mqtt.password = pass
            }
        }
        mqtt.keepAlive = 60
        mqtt.autoReconnect = false
        mqtt.delegate = self
        client = mqtt

        connectionState = .reconnecting
        log(.mqtt, "Connecting to \(settings.mqttHost):\(settings.mqttPort)…")
        _ = mqtt.connect()
    }

    func disconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        client?.disconnect()
        client = nil
        connectionState = .disconnected
    }

    func testConnection(completion: @escaping @Sendable (Bool, String) -> Void) {
        connect()
        Task { @MainActor in
            // Give it 5 seconds to connect, then report
            try? await Task.sleep(for: .seconds(5))
            let ok = self.connectionState == .connected
            completion(ok, ok ? "Connected successfully" : "Connection failed")
        }
    }

    // MARK: - Publishing

    func publishDiscovery(for person: TrackedPerson) {
        guard client != nil else { return }
        let slug = makeSlug(for: person)
        let topic = "homeassistant/device_tracker/\(slug)/config"
        let payload: [String: Any] = [
            "name": person.displayName,
            "unique_id": "fmf_\(slug)",
            "state_topic": "\(settings.mqttTopicPrefix)\(slug)/state",
            "json_attributes_topic": "\(settings.mqttTopicPrefix)\(slug)/attributes",
            "source_type": "gps"
        ]
        publishJSON(topic: topic, payload: payload, retain: true)
    }

    func publishLocation(for person: TrackedPerson, location: LocationUpdate) {
        guard let client else { return }
        let slug = makeSlug(for: person)
        let prefix = settings.mqttTopicPrefix

        // State message: "home" or "not_home"
        let stateMsg = CocoaMQTTMessage(topic: prefix + slug + "/state",
                                        string: location.haState, qos: .qos1, retained: false)
        client.publish(stateMsg)

        // Attributes message
        let iso = ISO8601DateFormatter()
        let attrs: [String: Any] = [
            "latitude":           location.latitude,
            "longitude":          location.longitude,
            "gps_accuracy":       location.horizontalAccuracy,
            "last_update":        iso.string(from: Date()),              // when our app polled
            "location_timestamp": iso.string(from: location.timestamp),  // when device recorded it
            "motion_state":       location.motionStateDescription.lowercased(),
            "location_label":     location.displayLabel
        ]
        publishJSON(topic: prefix + slug + "/attributes", payload: attrs, retain: true)
        log(.mqtt, "Published \(person.displayName) → \(location.haState) (\(location.displayLabel))")
    }

    // MARK: - Helpers

    private func publishJSON(topic: String, payload: [String: Any], retain: Bool) {
        guard let client,
              let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return }
        let msg = CocoaMQTTMessage(topic: topic, string: json, qos: .qos1, retained: retain)
        client.publish(msg)
    }

    private func makeSlug(for person: TrackedPerson) -> String {
        person.displayName
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "@", with: "_at_")
            .replacingOccurrences(of: "+", with: "")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
    }

    private func log(_ level: LogEntry.Level, _ message: String) {
        onLog?(level, message)
    }

    private func scheduleReconnect() {
        reconnectTask?.cancel()
        reconnectAttempts += 1
        guard reconnectAttempts <= 10 else { return }
        let delay = min(Double(reconnectAttempts) * 5.0, 60.0)
        connectionState = .reconnecting
        log(.warn, "Reconnecting in \(Int(delay))s (attempt \(reconnectAttempts))…")
        reconnectTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self.connect()
        }
    }
}

// MARK: - CocoaMQTTDelegate

extension MQTTService: CocoaMQTTDelegate {
    nonisolated func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        // Extract the comparison before crossing actor boundary to avoid
        // Swift 6 data-race warnings on non-Sendable CocoaMQTTConnAck.
        let accepted = (ack == .accept)
        let ackDescription = "\(ack)"
        Task { @MainActor in
            if accepted {
                self.connectionState = .connected
                self.reconnectAttempts = 0
                self.reconnectTask?.cancel()
                self.log(.mqtt, "Connected ✓")
                self.onConnected?()
            } else {
                self.log(.error, "Connection rejected: \(ackDescription)")
                self.scheduleReconnect()
            }
        }
    }

    nonisolated func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: (any Error)?) {
        Task { @MainActor in
            self.connectionState = .disconnected
            if let err {
                self.log(.warn, "Disconnected: \(err.localizedDescription)")
                self.scheduleReconnect()
            }
        }
    }

    nonisolated func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {}
    nonisolated func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {}
    nonisolated func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16) {}
    nonisolated func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopics success: NSDictionary, failed: [String]) {}
    nonisolated func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopics topics: [String]) {}
    nonisolated func mqttDidPing(_ mqtt: CocoaMQTT) {}
    nonisolated func mqttDidReceivePong(_ mqtt: CocoaMQTT) {}
}
