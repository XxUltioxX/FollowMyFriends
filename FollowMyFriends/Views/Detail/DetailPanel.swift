import SwiftUI
import MapKit

struct DetailPanel: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if let person = appState.selectedPerson {
                PersonDetailView(person: person)
            } else {
                EmptyDetailState()
            }
        }
        .background(Color.surface.opacity(0.5))
        .background(.ultraThinMaterial)
    }
}

// MARK: - Empty State

private struct EmptyDetailState: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "location.north.circle")
                .font(.system(size: 40))
                .foregroundStyle(Color.textTertiary)
            Text("Select a person")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.textSecondary)
            Text("Click a person card to see\nlocation details here.")
                .font(.system(size: 12))
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Person Detail

private struct PersonDetailView: View {
    let person: TrackedPerson

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // ── Avatar Header ─────────────────────────────────────────
                VStack(spacing: 10) {
                    AvatarView(person: person)
                        .scaleEffect(60.0 / 46.0)
                        .frame(width: 60, height: 60)

                    VStack(spacing: 3) {
                        Text(person.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                        Text(person.identifier)
                            .font(.system(size: 11).monospaced())
                            .foregroundStyle(Color.textTertiary)
                    }

                    // Online badge
                    HStack(spacing: 5) {
                        Circle()
                            .fill(person.isOnline ? Color.accentGreen : Color(hex: "6B6B75"))
                            .frame(width: 6, height: 6)
                        Text(person.isOnline ? "Tracked" : "No data")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(person.isOnline ? Color.accentGreen : Color.textTertiary)
                    }
                }
                .padding(.top, 24)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .bottom) { Divider().background(Color.border) }

                // ── Location ──────────────────────────────────────────────
                if let loc = person.lastLocation {
                    DetailSection(title: "Location") {
                        VStack(spacing: 10) {
                            // Live map
                            let coord = CLLocationCoordinate2D(
                                latitude: loc.latitude,
                                longitude: loc.longitude
                            )
                            Map(initialPosition: .region(MKCoordinateRegion(
                                center: coord,
                                span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
                            ))) {
                                Marker("", coordinate: coord)
                                    .tint(person.avatarColor)
                            }
                            .frame(height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .id("\(loc.latitude),\(loc.longitude)")
                            .overlay(
                                LocationLabelPill(label: loc.displayLabel,
                                                  motion: loc.motionStateDescription)
                                    .padding(8),
                                alignment: .topLeading
                            )

                            DetailRow(label: "Motion",    value: loc.motionStateDescription)
                            DetailRow(label: "Accuracy",  value: "±\(Int(loc.horizontalAccuracy))m")
                            DetailRow(label: "Speed",
                                      value: loc.speed >= 0
                                        ? String(format: "%.1f m/s", loc.speed)
                                        : "Unknown")
                            DetailRow(label: "Last seen", value: loc.relativeTime)
                        }
                    }

                    // ── MQTT ──────────────────────────────────────────────
                    DetailSection(title: "MQTT") {
                        VStack(spacing: 8) {
                            let slug = person.displayName
                                .lowercased()
                                .replacingOccurrences(of: " ", with: "_")
                            DetailRow(label: "State",
                                      value: loc.haState,
                                      valueColor: loc.isHome ? Color.accentGreen : Color.textSecondary)
                            DetailRow(label: "Topic",
                                      value: "…/\(slug)/state",
                                      monospace: true)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Payload preview")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.textTertiary)
                                Text("""
                                    {
                                      "latitude": \(String(format: "%.6f", loc.latitude)),
                                      "longitude": \(String(format: "%.6f", loc.longitude)),
                                      "gps_accuracy": \(Int(loc.horizontalAccuracy))
                                    }
                                    """)
                                    .font(.system(size: 9).monospaced())
                                    .foregroundStyle(Color.textTertiary)
                                    .padding(8)
                                    .background(Color.background)
                                    .cornerRadius(6)
                            }
                        }
                    }
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "location.slash")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.textTertiary)
                        Text("No location data")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textTertiary)
                    }
                    .padding(32)
                }
            }
        }
    }
}

// MARK: - Detail Section

private struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.textTertiary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 16)

            content
                .padding(.horizontal, 16)
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) { Divider().background(Color.border).padding(.top, 4) }
    }
}

// MARK: - Detail Row

private struct DetailRow: View {
    let label: String
    let value: String
    var valueColor: Color = Color.textSecondary
    var monospace: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Color.textTertiary)
            Spacer()
            Text(value)
                .font(monospace ? .system(size: 11).monospaced() : .system(size: 12))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
