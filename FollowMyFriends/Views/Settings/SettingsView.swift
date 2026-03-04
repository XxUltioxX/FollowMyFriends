import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    // Local form state — committed on Save
    @State private var form = AppSettings()
    @State private var mqttPassword = ""
    @State private var mqttTestResult: String?
    @State private var mqttTestOK: Bool = false
    @State private var isTesting = false
    @State private var saveConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ────────────────────────────────────────────────────
            HStack {
                Text("Settings")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                if saveConfirmation {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.accentGreen)
                        .transition(.opacity)
                }
                Button("Save") {
                    saveForm()
                }
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.accentBlue)
                .foregroundStyle(.white)
                .cornerRadius(7)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .frame(height: 56)
            .overlay(alignment: .bottom) { Divider().background(Color.border) }

            ScrollView {
                VStack(spacing: 24) {
                    mqttSection
                    pollingSection
                    nightModeSection
                    keyFileSection
                    applicationSection
                }
                .padding(20)
                .padding(.bottom, 40)
            }
        }
        .onAppear { form = appState.settings; mqttPassword = KeychainHelper.readPassword() ?? "" }
    }

    // MARK: - MQTT Section

    private var mqttSection: some View {
        SettingsSection(title: "MQTT Connection", icon: "wifi", iconColor: Color.accentBlue) {
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    FormField(label: "Host") {
                        TextField("192.168.1.100", text: $form.mqttHost)
                            .formFieldStyle()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    FormField(label: "Port") {
                        TextField("1883", value: $form.mqttPort, format: .number)
                            .formFieldStyle()
                            .frame(width: 80)
                    }
                }

                HStack(spacing: 12) {
                    FormField(label: "Username") {
                        TextField("homeassistant", text: $form.mqttUsername)
                            .formFieldStyle()
                    }
                    FormField(label: "Password") {
                        SecureField("••••••••", text: $mqttPassword)
                            .formFieldStyle()
                    }
                }

                FormField(label: "Topic Prefix") {
                    TextField("homeassistant/device_tracker/", text: $form.mqttTopicPrefix)
                        .formFieldStyle()
                        .font(.system(size: 12).monospaced())
                }

                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(mqttDotColor)
                            .frame(width: 7, height: 7)
                        Text(mqttStatusText)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textSecondary)
                    }
                    Spacer()
                    if let result = mqttTestResult {
                        Text(result)
                            .font(.system(size: 11))
                            .foregroundStyle(mqttTestOK ? Color.accentGreen : Color.accentRed)
                    }
                    Button {
                        runMQTTTest()
                    } label: {
                        HStack(spacing: 6) {
                            if isTesting {
                                ProgressView().scaleEffect(0.6).frame(width: 12, height: 12)
                            }
                            Text("Test Connection")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.elevated)
                        .foregroundStyle(Color.textSecondary)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.borderFocus, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isTesting)
                }
            }
        }
    }

    // MARK: - Polling Section

    private var pollingSection: some View {
        SettingsSection(title: "Polling Schedule", icon: "clock.arrow.circlepath", iconColor: Color.accentGreen) {
            VStack(spacing: 18) {
                SliderRow(
                    label: "Min Interval",
                    value: $form.pollIntervalMin,
                    range: 45...600,
                    suffix: "s"
                )
                SliderRow(
                    label: "Max Interval",
                    value: $form.pollIntervalMax,
                    range: 60...1200,
                    suffix: "s"
                )
                HStack {
                    Text("Randomize between min and max")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                    Spacer()
                    Toggle("", isOn: $form.randomizeInterval)
                        .toggleStyle(.switch)
                        .scaleEffect(0.8)
                }
                SliderRow(
                    label: "Find My wait time",
                    value: $form.findMyWaitSeconds,
                    range: 5...30,
                    suffix: "s"
                )
            }
        }
    }

    // MARK: - Night Mode Section

    private var nightModeSection: some View {
        SettingsSection(title: "Night Mode", icon: "moon.stars.fill", iconColor: Color.accentAmber) {
            VStack(spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pause tracking at night")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.textPrimary)
                        Text("Stops polling to reduce noise")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textTertiary)
                    }
                    Spacer()
                    Toggle("", isOn: $form.nightModeEnabled)
                        .toggleStyle(.switch)
                        .scaleEffect(0.8)
                        .tint(Color.accentAmber)
                }

                HStack(spacing: 12) {
                    FormField(label: "Start") {
                        TextField("23:00", text: $form.nightModeStart)
                            .formFieldStyle()
                    }
                    FormField(label: "End") {
                        TextField("07:00", text: $form.nightModeEnd)
                            .formFieldStyle()
                    }
                }
                .opacity(form.nightModeEnabled ? 1 : 0.4)
                .disabled(!form.nightModeEnabled)

                if form.nightModeEnabled {
                    Text("Tracking paused from \(form.nightModeStart) to \(form.nightModeEnd)")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.accentAmber.opacity(0.8))
                }
            }
        }
    }

    // MARK: - Key File Section

    private var keyFileSection: some View {
        SettingsSection(title: "Key File", icon: "key.fill", iconColor: Color(hex: "A855F7")) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    TextField("Path to LocalStorage.key…", text: $form.keyFilePath)
                        .formFieldStyle()
                        .font(.system(size: 11).monospaced())

                    Button("Auto-Detect") {
                        appState.autoDetectKey()
                        form.keyFilePath = appState.settings.keyFilePath
                    }
                    .secondaryButton()

                    Button("Browse…") {
                        browseForKey()
                    }
                    .secondaryButton()
                }

                HStack(spacing: 6) {
                    Image(systemName: appState.keyIsValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(appState.keyIsValid ? Color.accentGreen : Color.accentRed)
                    Text(appState.keyStatusMessage)
                        .font(.system(size: 11))
                        .foregroundStyle(appState.keyIsValid ? Color.accentGreen : Color.accentRed)
                }
            }
        }
    }

    // MARK: - Application Section

    private var applicationSection: some View {
        SettingsSection(title: "Application", icon: "app.badge", iconColor: Color.textSecondary) {
            VStack(spacing: 12) {
                ToggleRow(label: "Launch at macOS startup",
                          detail: "Uses SMAppService",
                          value: $form.launchAtStartup)
                ToggleRow(label: "Show in Dock",
                          detail: "Uncheck to run as menu-bar-only app",
                          value: $form.showInDock)

                Divider()

                Button {
                    appState.openDatabasePicker()
                } label: {
                    HStack {
                        Image(systemName: "folder.badge.gearshape")
                        Text("Grant FindMy Folder Access…")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(Color.accentBlue)
                }
                .buttonStyle(.plain)

                Text("Required once — grants read access to LocalStorage.db and its WAL file.")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.textTertiary)

                Button {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack {
                        Image(systemName: "lock.shield")
                        Text("Request Full Disk Access…")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(Color.accentBlue)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private var mqttDotColor: Color {
        switch appState.mqttConnectionState {
        case .connected:    return Color.accentGreen
        case .disconnected: return Color.accentRed
        case .reconnecting: return Color.accentAmber
        }
    }

    private var mqttStatusText: String {
        switch appState.mqttConnectionState {
        case .connected:    return "Connected"
        case .disconnected: return "Disconnected"
        case .reconnecting: return "Reconnecting…"
        }
    }

    private func saveForm() {
        if !mqttPassword.isEmpty { KeychainHelper.savePassword(mqttPassword) }
        appState.settings = form
        appState.saveSettings()
        Task { await appState.validateKey() }

        withAnimation { saveConfirmation = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { saveConfirmation = false }
        }
    }

    private func runMQTTTest() {
        isTesting = true
        mqttTestResult = nil
        let testService = MQTTService(settings: form)
        testService.testConnection { ok, msg in
            Task { @MainActor in
                self.isTesting = false
                self.mqttTestOK = ok
                self.mqttTestResult = msg
            }
        }
    }

    private func browseForKey() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = []
        panel.message = "Select LocalStorage.key (32-byte raw AES key)"
        if panel.runModal() == .OK, let url = panel.url {
            form.keyFilePath = url.path
        }
    }
}

// MARK: - Slider Row

private struct SliderRow: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let suffix: String

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                Text("\(value)\(suffix)")
                    .font(.system(size: 12, weight: .semibold).monospaced())
                    .foregroundStyle(Color.accentBlue)
            }
            Slider(value: Binding(
                get: { Double(value) },
                set: { value = Int($0) }
            ), in: Double(range.lowerBound)...Double(range.upperBound))
            .tint(Color.accentBlue)
        }
    }
}

// MARK: - Toggle Row

private struct ToggleRow: View {
    let label: String
    let detail: String
    @Binding var value: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textPrimary)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
            }
            Spacer()
            Toggle("", isOn: $value)
                .toggleStyle(.switch)
                .scaleEffect(0.8)
        }
    }
}

// MARK: - FormField

private struct FormField<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.textTertiary)
            content
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - View extensions

private extension TextField {
    func formFieldStyle() -> some View {
        self
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.background)
            .foregroundStyle(Color.textPrimary)
            .cornerRadius(7)
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.border, lineWidth: 0.5)
            )
    }
}

private extension SecureField {
    func formFieldStyle() -> some View {
        self
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.background)
            .foregroundStyle(Color.textPrimary)
            .cornerRadius(7)
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.border, lineWidth: 0.5)
            )
    }
}

private extension View {
    func formFieldStyle() -> some View {
        self
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.background)
            .foregroundStyle(Color.textPrimary)
            .cornerRadius(7)
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.border, lineWidth: 0.5)
            )
    }

    func secondaryButton() -> some View {
        self
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.elevated)
            .foregroundStyle(Color.textSecondary)
            .cornerRadius(7)
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.borderFocus, lineWidth: 0.5)
            )
            .buttonStyle(.plain)
    }
}
