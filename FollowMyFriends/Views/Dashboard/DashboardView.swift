import SwiftUI

struct DashboardView: View {
    @Environment(AppState.self) private var appState

    var trackedPeople: [TrackedPerson] {
        appState.trackedPeople.filter { $0.isActive }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ────────────────────────────────────────────────────
            HStack {
                Text("Tracking \(trackedPeople.count) people")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                // Countdown + Start/Stop
                HStack(spacing: 10) {
                    if appState.isTracking {
                        Text("Next in \(appState.scheduler.nextPollIn)s")
                            .font(.system(size: 11).monospaced())
                            .foregroundStyle(Color.textTertiary)
                    }

                    ManualRefreshButton()
                    TrackingToggleButton()
                }
            }
            .padding(.horizontal, 20)
            .frame(height: 56)
            .overlay(alignment: .bottom) {
                Divider().background(Color.border)
            }

            // ── Night Mode Banner ─────────────────────────────────────────
            if appState.settings.nightModeEnabled &&
               appState.scheduler.isRunning == false {
                NightModeBanner()
            }

            // ── Onboarding card (no key configured) ──────────────────────
            if !appState.keyIsValid {
                OnboardingCard()
            }

            // ── Full Disk Access warning ──────────────────────────────────
            if appState.needsFullDiskAccess {
                FullDiskAccessBanner()
            }

            // ── Person List ───────────────────────────────────────────────
            ScrollView {
                LazyVStack(spacing: 8) {
                    if trackedPeople.isEmpty {
                        EmptyTrackerState()
                    } else {
                        ForEach(trackedPeople) { person in
                            PersonCard(person: person)
                        }
                    }
                }
                .padding(16)
            }
        }
    }
}

// MARK: - Subviews

private struct ManualRefreshButton: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let throttled = appState.scheduler.secondsUntilManualAllowed > 0

        Button {
            appState.manualRefresh()
        } label: {
            HStack(spacing: 6) {
                if appState.isRefreshing {
                    ProgressView().scaleEffect(0.6).frame(width: 12, height: 12)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .medium))
                }
                Text(throttled
                     ? "Wait \(appState.scheduler.secondsUntilManualAllowed)s"
                     : "Manual Refresh")
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.elevated)
            .foregroundStyle(throttled ? Color.textTertiary : Color.textPrimary)
            .cornerRadius(7)
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.borderFocus, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(throttled || appState.isRefreshing)
    }
}

private struct TrackingToggleButton: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Button {
            if appState.isTracking { appState.stopTracking() }
            else { appState.startTracking() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: appState.isTracking ? "stop.fill" : "play.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text(appState.isTracking ? "Stop" : "Start Tracking")
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(appState.isTracking ? Color.accentBlue : Color.accentBlue)
            .foregroundStyle(.white)
            .cornerRadius(7)
        }
        .buttonStyle(.plain)
    }
}

private struct EmptyTrackerState: View {
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.surface)
                    .frame(width: 64, height: 64)
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.top, 60)

            Text("No people tracked")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.textSecondary)
            Text("Go to the People tab to add friends\nfrom your Find My network.")
                .font(.system(size: 12))
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct OnboardingCard: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "key.slash")
                .font(.system(size: 22))
                .foregroundStyle(Color.accentAmber)

            VStack(alignment: .leading, spacing: 2) {
                Text("Key file not configured")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text(appState.keyStatusMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
            }

            Spacer()

            Button("Configure in Settings") {
                // Settings tab switch handled via environment if needed
            }
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.accentAmber.opacity(0.15))
            .foregroundStyle(Color.accentAmber)
            .cornerRadius(6)
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.accentAmber.opacity(0.07))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.accentAmber.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}

private struct FullDiskAccessBanner: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "lock.shield")
                .font(.system(size: 20))
                .foregroundStyle(Color.accentAmber)

            VStack(alignment: .leading, spacing: 3) {
                Text("Database access required")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text("Click \"Select File\" to grant access to LocalStorage.db — or enable Full Disk Access in System Settings → Privacy & Security.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            VStack(spacing: 6) {
                Button("Select File") {
                    appState.openDatabasePicker()
                }
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.accentAmber.opacity(0.2))
                .foregroundStyle(Color.accentAmber)
                .cornerRadius(6)
                .buttonStyle(.plain)

                Button("Open Settings") {
                    NSWorkspace.shared.open(
                        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
                    )
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.textTertiary)
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color.accentAmber.opacity(0.07))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.accentAmber.opacity(0.25), lineWidth: 1)
        )
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}
