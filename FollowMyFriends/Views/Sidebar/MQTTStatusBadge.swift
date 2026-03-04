import SwiftUI

struct MQTTStatusBadge: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                statusDot
                Text(statusLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
            }
            Text("\(appState.settings.mqttHost):\(appState.settings.mqttPort)")
                .font(.system(size: 10, weight: .regular).monospaced())
                .foregroundStyle(Color.textTertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var statusDot: some View {
        let state = appState.mqttConnectionState
        Circle()
            .fill(dotColor(state))
            .frame(width: 7, height: 7)
            .shadow(color: dotColor(state).opacity(0.6), radius: 4)
            .modifier(PulsingModifier(active: state == .reconnecting))
    }

    private var statusLabel: String {
        switch appState.mqttConnectionState {
        case .connected:    return "Connected"
        case .disconnected: return "Disconnected"
        case .reconnecting: return "Reconnecting…"
        }
    }

    private func dotColor(_ state: MQTTConnectionState) -> Color {
        switch state {
        case .connected:    return Color.accentGreen
        case .disconnected: return Color.accentRed
        case .reconnecting: return Color.accentAmber
        }
    }
}

private struct PulsingModifier: ViewModifier {
    let active: Bool
    @State private var opacity: Double = 1

    func body(content: Content) -> some View {
        content
            .opacity(active ? opacity : 1)
            .onAppear {
                guard active else { return }
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    opacity = 0.3
                }
            }
    }
}
