import SwiftUI

enum AppTab: String, CaseIterable, Hashable {
    case tracker  = "Tracker"
    case people   = "People"
    case settings = "Settings"
    case logs     = "Logs"

    var systemImage: String {
        switch self {
        case .tracker:  return "mappin.and.ellipse"
        case .people:   return "person.2"
        case .settings: return "gear"
        case .logs:     return "doc.text.below.ecg"
        }
    }
}

struct MainWindow: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: AppTab = .tracker

    var body: some View {
        HStack(spacing: 0) {
            // ── Left Sidebar (220 px) ──────────────────────────────────────
            SidebarView(selectedTab: $selectedTab)
                .frame(width: 220)

            Divider()
                .background(Color.border)

            // ── Center Content (flexible) ─────────────────────────────────
            Group {
                switch selectedTab {
                case .tracker:  DashboardView()
                case .people:   PeopleView()
                case .settings: SettingsView()
                case .logs:     LogView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
                .background(Color.border)

            // ── Right Detail Panel (300 px) ───────────────────────────────
            DetailPanel()
                .frame(width: 300)
        }
        .frame(width: 1100, height: 720)
        .background(Color.background)
        .preferredColorScheme(.dark)
    }
}
