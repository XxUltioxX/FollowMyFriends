import SwiftUI

struct SidebarView: View {
    @Binding var selectedTab: AppTab
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            // ── Logo ──────────────────────────────────────────────────────
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentBlue.opacity(0.1))
                        .frame(width: 28, height: 28)
                        .shadow(color: Color.accentBlue.opacity(0.35), radius: 8)
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.accentBlue)
                        .rotationEffect(.degrees(45))
                }
                Text("FollowMyFriends")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .overlay(alignment: .bottom) {
                Divider().background(Color.border.opacity(0.5))
            }

            // ── Navigation ────────────────────────────────────────────────
            VStack(spacing: 2) {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    SidebarItem(tab: tab, isSelected: selectedTab == tab) {
                        selectedTab = tab
                    }
                }
            }
            .padding(12)

            Spacer()

            // ── MQTT Status Badge ─────────────────────────────────────────
            MQTTStatusBadge()
                .padding(16)
                .overlay(alignment: .top) {
                    Divider().background(Color.border)
                }
        }
        .background(Color.background.opacity(0.95))
        .background(.ultraThinMaterial)
    }
}

private struct SidebarItem: View {
    let tab: AppTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 18)
                Text(tab.rawValue)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                isSelected
                    ? Color.accentBlue.opacity(0.15)
                    : Color.clear
            )
            .foregroundStyle(isSelected ? Color.accentBlue.opacity(0.9) : Color.textSecondary)
            .cornerRadius(7)
        }
        .buttonStyle(.plain)
    }
}
