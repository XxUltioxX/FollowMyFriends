import SwiftUI

struct NightModeBanner: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "moon.fill")
                .font(.system(size: 12))
                .foregroundStyle(Color.accentAmber)
            Text("Night mode active — tracking paused until \(appState.settings.nightModeEnd)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.accentAmber)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.accentAmber.opacity(0.08))
        .overlay(alignment: .bottom) {
            Divider()
                .background(Color.accentAmber.opacity(0.2))
        }
    }
}
