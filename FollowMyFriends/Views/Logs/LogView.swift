import SwiftUI

struct LogView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""
    @State private var selectedLevel: LogFilter = .all
    @State private var autoScroll = true

    private var filtered: [LogEntry] {
        appState.logs.filter { entry in
            let matchesLevel: Bool
            switch selectedLevel {
            case .all:    matchesLevel = true
            case .errors: matchesLevel = entry.level == .error
            case .mqtt:   matchesLevel = entry.level == .mqtt
            case .findmy: matchesLevel = entry.level == .findmy
            case .system: matchesLevel = entry.level == .info || entry.level == .warn
            }
            let matchesSearch = searchText.isEmpty ||
                entry.message.localizedCaseInsensitiveContains(searchText)
            return matchesLevel && matchesSearch
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Toolbar ───────────────────────────────────────────────────
            HStack(spacing: 10) {
                // Search
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textTertiary)
                    TextField("Search logs…", text: $searchText)
                        .font(.system(size: 12))
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.elevated)
                .cornerRadius(7)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color.border, lineWidth: 0.5)
                )
                .frame(maxWidth: 220)

                // Level filter
                Picker("", selection: $selectedLevel) {
                    ForEach(LogFilter.allCases, id: \.self) { f in
                        Text(f.label).tag(f)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 110)

                Spacer()

                // Auto-scroll toggle
                Toggle(isOn: $autoScroll) {
                    Text("Auto-scroll")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textTertiary)
                }
                .toggleStyle(.checkbox)
                .scaleEffect(0.9)

                Button("Export…") { exportLogs() }
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.elevated)
                    .foregroundStyle(Color.textSecondary)
                    .cornerRadius(6)
                    .buttonStyle(.plain)

                Button("Clear") {
                    appState.logs.removeAll()
                }
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.accentRed.opacity(0.12))
                .foregroundStyle(Color.accentRed)
                .cornerRadius(6)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .overlay(alignment: .bottom) { Divider().background(Color.border) }

            // ── Log List ──────────────────────────────────────────────────
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filtered.reversed()) { entry in
                            LogRow(entry: entry)
                                .id(entry.id)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onChange(of: appState.logs.count) { _, _ in
                    if autoScroll, let last = filtered.last {
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            // ── Footer ────────────────────────────────────────────────────
            HStack {
                Image(systemName: "doc.text")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.textTertiary)
                Text("Logging to ~/Library/Logs/FollowMyFriends/app.log")
                    .font(.system(size: 10).monospaced())
                    .foregroundStyle(Color.textTertiary)
                Spacer()
                Text("\(filtered.count) entries")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, 14)
            .frame(height: 28)
            .background(Color.elevated.opacity(0.3))
            .overlay(alignment: .top) { Divider().background(Color.border) }
        }
    }

    private func exportLogs() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "fmf-logs.txt"
        panel.allowedContentTypes = [.plainText]
        if panel.runModal() == .OK, let url = panel.url {
            let text = appState.logs.map { e in
                "[\(e.formattedTime)] [\(e.level.rawValue)] \(e.message)"
            }.joined(separator: "\n")
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

// MARK: - Log Filter Enum

enum LogFilter: CaseIterable, Hashable {
    case all, errors, mqtt, findmy, system

    var label: String {
        switch self {
        case .all:    return "All"
        case .errors: return "Errors"
        case .mqtt:   return "MQTT"
        case .findmy: return "FindMy"
        case .system: return "System"
        }
    }
}
