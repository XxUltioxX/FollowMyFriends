import Foundation
import SwiftUI
import Observation
import AppKit

/// Root application state — owns all services, holds all observable data.
@Observable
@MainActor
final class AppState {

    // MARK: - Settings & People

    var settings: AppSettings
    var trackedPeople: [TrackedPerson] = []
    var availableIdentifiers: [String] = []  // populated by DB scan

    // MARK: - Tracking Runtime

    var isTracking = false
    var isRefreshing = false
    var lastRefreshTime: Date?
    var selectedPersonId: UUID?

    // MARK: - Key Status

    var keyIsValid = false
    var keyStatusMessage = "Not checked"
    var needsFullDiskAccess = false

    // MARK: - Logs

    var logs: [LogEntry] = []

    // MARK: - Services

    let mqttService: MQTTService
    let scheduler: TrackingScheduler
    let launcher: FindMyLauncher
    let walWatcher = WALWatcher()
    let notificationService = NotificationService.shared

    // MARK: - Init

    init() {
        let loaded = AppSettings.load()
        self.settings = loaded
        self.mqttService = MQTTService(settings: loaded)
        self.scheduler = TrackingScheduler(settings: loaded)
        self.launcher = FindMyLauncher()
        self.trackedPeople = loaded.trackedPeople

        setupServiceCallbacks()
        notificationService.requestPermission()
        addLog(.info, "FollowMyFriends started")

        NotificationCenter.default.addObserver(
            forName: .init("DatabaseReaderDiagnostics"),
            object: nil,
            queue: .main
        ) { [weak self] note in
            if let diag = note.userInfo?["diag"] as? String {
                Task { @MainActor [weak self] in
                    self?.addLog(.findmy, "WAL: \(diag)")
                }
            }
        }

        Task {
            await validateKey()
        }
    }

    // MARK: - Service Wiring

    private func setupServiceCallbacks() {
        mqttService.onLog = { [weak self] level, msg in
            // Closure is @Sendable; hop to MainActor for the state mutation
            Task { @MainActor [weak self] in
                self?.addLog(level, msg)
            }
        }
        mqttService.onConnected = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.isTracking else { return }
                // Re-publish discovery + last known location for all active people
                for person in self.trackedPeople where person.isActive {
                    self.mqttService.publishDiscovery(for: person)
                    if let loc = person.lastLocation {
                        self.mqttService.publishLocation(for: person, location: loc)
                    }
                }
            }
        }
        launcher.onLog = { [weak self] msg in
            self?.addLog(.findmy, msg)
        }
        scheduler.onPoll = { [weak self] in
            await self?.performPoll()
        }
        walWatcher.onWALWritten = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.performQuickRead()
            }
        }
        walWatcher.onLog = { [weak self] msg in
            Task { @MainActor [weak self] in
                self?.addLog(.info, msg)
            }
        }
    }

    // MARK: - Key Management

    func validateKey() async {
        guard !settings.keyFilePath.isEmpty else {
            keyIsValid = false
            keyStatusMessage = "No key file configured"
            return
        }

        // Step 1: verify the key file itself is readable and 32 bytes
        let key: Data
        do {
            key = try FindMyDecryptor.loadKey(from: settings.keyFilePath)
        } catch {
            keyIsValid = false
            keyStatusMessage = error.localizedDescription
            addLog(.error, "Key file error: \(error.localizedDescription)")
            return
        }

        // Step 2: try to verify against the live DB (requires Full Disk Access)
        let resolvedDBPath = settings.customDBPath.isEmpty ? DatabaseReader.dbPath : settings.customDBPath
        let dbURL = URL(fileURLWithPath: resolvedDBPath)
        do {
            keyIsValid = try FindMyDecryptor.verifyKey(key, dbPath: dbURL)
            needsFullDiskAccess = false
            keyStatusMessage = keyIsValid
                ? "Key valid (\(key.count) bytes) ✓"
                : "Key verification failed — key may be wrong"
            if keyIsValid {
                addLog(.info, "Key verified ✓")
            } else {
                addLog(.error, "Key verification failed")
            }
        } catch FindMyDecryptor.Error.fileReadError {
            // DB isn't accessible — needs Full Disk Access.
            // Key file itself loaded fine; mark valid so the user can proceed.
            keyIsValid = true
            needsFullDiskAccess = true
            keyStatusMessage = "Key loaded (\(key.count) bytes) — Full Disk Access required"
            addLog(.warn, "FindMy DB not accessible. Go to System Settings → Privacy & Security → Full Disk Access and add FollowMyFriends.")
        } catch {
            keyIsValid = false
            keyStatusMessage = error.localizedDescription
            addLog(.error, "Key error: \(error.localizedDescription)")
        }
    }

    // MARK: - Tracking Control

    func startTracking() {
        guard keyIsValid else {
            addLog(.error, "Cannot start: key invalid")
            return
        }
        isTracking = true
        scheduler.start()
        mqttService.connect()  // discovery + attributes re-published via onConnected
        startWALWatcher()
        addLog(.info, "Tracking started")
    }

    func stopTracking() {
        isTracking = false
        scheduler.stop()
        walWatcher.stop()
        mqttService.disconnect()
        addLog(.info, "Tracking stopped")
    }

    private func startWALWatcher() {
        let resolvedPath = settings.customDBPath.isEmpty ? DatabaseReader.dbPath : settings.customDBPath
        let walPath = resolvedPath + "-wal"
        walWatcher.start(walPath: walPath)
        addLog(.info, "WAL watcher started")
    }

    func manualRefresh() {
        let allowed = scheduler.triggerManualPoll()
        if !allowed {
            addLog(.warn, "Manual refresh throttled — wait \(scheduler.secondsUntilManualAllowed)s")
        }
    }

    // MARK: - Poll Pipeline

    func performPoll() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        addLog(.findmy, "Polling started…")

        defer {
            Task { @MainActor in
                self.isRefreshing = false
                self.lastRefreshTime = Date()
            }
        }

        // Launch Find My to trigger a fresh server poll
        await launcher.triggerRefresh(waitSeconds: settings.findMyWaitSeconds)

        // Decrypt DB on background queue
        do {
            let keyPath = settings.keyFilePath
            let customDB = settings.customDBPath
            let records = try await Task.detached(priority: .userInitiated) {
                try DatabaseReader.readFriends(keyPath: keyPath, customDBPath: customDB)
            }.value

            process(records: records)
            addLog(.findmy, "Read \(records.count) friends from database")
        } catch {
            addLog(.error, "Poll failed: \(error.localizedDescription)")
        }
    }

    /// Lightweight read triggered by the WAL watcher — no FindMy launch, just reads the DB.
    func performQuickRead() async {
        guard isTracking, !isRefreshing else { return }
        addLog(.findmy, "WAL updated — reading fresh location data…")
        isRefreshing = true
        defer {
            Task { @MainActor in
                self.isRefreshing = false
                self.lastRefreshTime = Date()
            }
        }
        do {
            let keyPath = settings.keyFilePath
            let customDB = settings.customDBPath
            let records = try await Task.detached(priority: .userInitiated) {
                try DatabaseReader.readFriends(keyPath: keyPath, customDBPath: customDB)
            }.value
            process(records: records)
            addLog(.findmy, "WAL read: \(records.count) friends updated")
        } catch {
            addLog(.error, "WAL read failed: \(error.localizedDescription)")
        }
    }

    private func process(records: [FriendRecord]) {
        // Update available identifiers for the People tab
        availableIdentifiers = records.compactMap { r in
            r.handleIdentifier.isEmpty ? nil : r.handleIdentifier
        }

        for i in trackedPeople.indices {
            let person = trackedPeople[i]
            guard let record = records.first(where: {
                $0.handleIdentifier == person.identifier
            }) else { continue }

            guard let blob = record.locationBlob,
                  let location = try? BplistParser.parseLocation(from: blob) else { continue }

            notificationService.checkArrivalDeparture(person: person, newLocation: location)

            // Log GPS fix freshness — ★ means the fix timestamp is newer than last read,
            // confirming live data even when coordinates haven't visibly changed.
            let prevTimestamp = person.lastLocation?.timestamp
            let isNewFix = prevTimestamp.map { location.timestamp > $0.addingTimeInterval(1) } ?? true
            let fixAge = Int(-location.timestamp.timeIntervalSinceNow)
            let ageStr = fixAge < 60 ? "\(fixAge)s" : "\(fixAge / 60)m \(fixAge % 60)s"
            let marker = isNewFix ? "★ " : "  "
            addLog(.findmy, "\(marker)\(person.displayName): GPS fix \(ageStr) ago  ±\(Int(location.horizontalAccuracy))m  \(location.motionStateDescription)")

            trackedPeople[i].lastLocation = location

            if isTracking && person.isActive {
                mqttService.publishLocation(for: person, location: location)
            }
        }
    }

    // MARK: - People Management

    func addPerson(identifier: String) {
        guard !trackedPeople.contains(where: { $0.identifier == identifier }) else { return }
        let palette = ["blue", "pink", "green", "purple", "orange", "red"]
        let color = palette[trackedPeople.count % palette.count]
        trackedPeople.append(TrackedPerson(identifier: identifier, avatarColorName: color))
        persistSettings()
        addLog(.info, "Added \(identifier) to tracking")
    }

    func removePerson(id: UUID) {
        trackedPeople.removeAll { $0.id == id }
        if selectedPersonId == id { selectedPersonId = nil }
        persistSettings()
    }

    func updatePerson(_ updated: TrackedPerson) {
        if let idx = trackedPeople.firstIndex(where: { $0.id == updated.id }) {
            trackedPeople[idx] = updated
            persistSettings()
        }
    }

    // MARK: - Settings Persistence

    func persistSettings() {
        var s = settings
        s.trackedPeople = trackedPeople
        settings = s
        settings.save()
        mqttService.configure(with: settings)
        scheduler.configure(with: settings)
    }

    func saveSettings() {
        persistSettings()
    }

    // MARK: - Database File Picker

    /// Opens NSOpenPanel so the user can explicitly grant access to the FindMy
    /// Application Support directory (covers LocalStorage.db AND LocalStorage.db-wal).
    /// macOS records user-intent access in TCC (kTCCServiceSystemPolicyUserAccess),
    /// which bypasses the FDA requirement for all files in the selected directory.
    func openDatabasePicker() {
        let panel = NSOpenPanel()
        panel.title = "Grant Access to FindMy Folder"
        panel.prompt = "Grant Access"
        panel.message = """
            Navigate to: Library → Group Containers → \
            group.com.apple.findmy.findmylocateagent → Library → Application Support
            Then click "Grant Access" to allow reading the database and WAL files.
            """
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        // Pre-navigate to the FindMy Application Support directory
        let dbDir = URL(fileURLWithPath: DatabaseReader.dbPath).deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: dbDir.path) {
            panel.directoryURL = dbDir
        }

        guard panel.runModal() == .OK, let url = panel.url else { return }

        // Derive the DB path from the selected directory
        settings.customDBPath = url.appendingPathComponent("LocalStorage.db").path
        // Save a security-scoped bookmark for persistence across launches
        if let bookmark = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            settings.dbBookmarkData = bookmark
        }
        saveSettings()
        addLog(.info, "Database folder access granted: \(url.path)")
        needsFullDiskAccess = false
        if isTracking { startWALWatcher() }
        Task { await validateKey() }
    }

    func autoDetectKey() {
        if let path = FindMyDecryptor.autoDetectKeyPath() {
            settings.keyFilePath = path
            Task { await validateKey() }
        } else {
            keyStatusMessage = "Key file not found in common locations"
        }
    }

    func scanDatabase() {
        Task {
            let keyPath = settings.keyFilePath
            let customDB = settings.customDBPath
            do {
                let records = try await Task.detached(priority: .userInitiated) {
                    try DatabaseReader.readFriends(keyPath: keyPath, customDBPath: customDB)
                }.value
                availableIdentifiers = records.compactMap { r in
                    r.handleIdentifier.isEmpty ? nil : r.handleIdentifier
                }
                addLog(.findmy, "Scan complete: \(records.count) friends found")
            } catch {
                addLog(.error, "Scan failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Logging

    func addLog(_ level: LogEntry.Level, _ message: String) {
        let entry = LogEntry(timestamp: Date(), level: level, message: message)
        logs.insert(entry, at: 0)
        if logs.count > 1000 { logs = Array(logs.prefix(1000)) }
        writeLogToFile(entry)
    }

    private func writeLogToFile(_ entry: LogEntry) {
        Task.detached(priority: .background) {
            let logDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)
                .first!.appendingPathComponent("Logs/FollowMyFriends")
            try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
            let logFile = logDir.appendingPathComponent("app.log")

            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let line = "[\(fmt.string(from: entry.timestamp))] [\(entry.level.rawValue)] \(entry.message)\n"

            guard let data = line.data(using: .utf8) else { return }
            if FileManager.default.fileExists(atPath: logFile.path),
               let fh = try? FileHandle(forWritingTo: logFile) {
                fh.seekToEndOfFile()
                fh.write(data)
                try? fh.close()
            } else {
                try? data.write(to: logFile)
            }
        }
    }

    // MARK: - Computed

    var selectedPerson: TrackedPerson? {
        guard let id = selectedPersonId else { return nil }
        return trackedPeople.first { $0.id == id }
    }

    var mqttConnectionState: MQTTConnectionState {
        mqttService.connectionState
    }
}
