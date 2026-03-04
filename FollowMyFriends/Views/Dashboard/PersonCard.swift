import SwiftUI

struct PersonCard: View {
    let person: TrackedPerson
    @Environment(AppState.self) private var appState

    private var isSelected: Bool { appState.selectedPersonId == person.id }
    private var location: LocationUpdate? { person.lastLocation }

    var body: some View {
        Button {
            appState.selectedPersonId = isSelected ? nil : person.id
        } label: {
            HStack(spacing: 14) {
                // ── Avatar ────────────────────────────────────────────────
                AvatarView(person: person)

                // ── Info ──────────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 5) {
                    // Row 1: name + last-seen
                    HStack {
                        Text(person.displayName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        if let loc = location {
                            Text(loc.relativeTime)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.textTertiary)
                        }
                    }

                    // Row 2: location pill + accuracy
                    HStack(spacing: 8) {
                        LocationLabelPill(label: location?.displayLabel ?? "Unknown",
                                          motion: location?.motionStateDescription ?? "Unknown")
                        if let loc = location {
                            Text("±\(Int(loc.horizontalAccuracy))m")
                                .font(.system(size: 10).monospaced())
                                .foregroundStyle(Color.textTertiary)
                        }
                    }

                    // Row 3: coordinates + MQTT status
                    HStack {
                        if let loc = location {
                            Text(String(format: "%.4f° N, %.4f° W",
                                        loc.latitude, abs(loc.longitude)))
                                .font(.system(size: 10).monospaced())
                                .foregroundStyle(Color.textTertiary)
                        } else {
                            Text("No location data")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.textTertiary)
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.accentGreen.opacity(0.6))
                                .frame(width: 5, height: 5)
                            Text("Published")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.textTertiary)
                        }
                    }
                }
            }
            .padding(14)
            .background(
                isSelected
                    ? Color.surface
                    : Color.surface.opacity(0.45)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected
                            ? Color.accentBlue.opacity(0.5)
                            : Color.border,
                        lineWidth: 1
                    )
            )
            .cornerRadius(12)
            .shadow(
                color: isSelected ? Color.accentBlue.opacity(0.08) : .clear,
                radius: 12
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Avatar

struct AvatarView: View {
    let person: TrackedPerson

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(person.avatarColor)
                .frame(width: 46, height: 46)
                .overlay(
                    Text(person.initials)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                )

            // Online indicator
            Circle()
                .fill(person.isOnline ? Color.accentGreen : Color(hex: "6B6B75"))
                .frame(width: 13, height: 13)
                .overlay(
                    Circle()
                        .stroke(Color.surface, lineWidth: 2.5)
                )
                .offset(x: 2, y: 2)
        }
    }
}

// MARK: - Location Label Pill

struct LocationLabelPill: View {
    let label: String
    let motion: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .medium))
            Text(label)
                .font(.system(size: 10, weight: .medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(pillBg)
        .foregroundStyle(pillFg)
        .overlay(
            Capsule()
                .stroke(pillFg.opacity(0.3), lineWidth: 0.5)
        )
        .clipShape(Capsule())
    }

    private var icon: String {
        if label.contains("Home") { return "house.fill" }
        if label.contains("Work") { return "briefcase.fill" }
        if motion == "Driving" { return "car.fill" }
        return "mappin.fill"
    }

    private var pillBg: Color {
        if label.contains("Home") { return Color.accentBlue.opacity(0.12) }
        if label.contains("Work") { return Color(hex: "A855F7").opacity(0.12) }
        if motion == "Driving" { return Color.accentAmber.opacity(0.12) }
        return Color(hex: "6B6B75").opacity(0.12)
    }

    private var pillFg: Color {
        if label.contains("Home") { return Color.accentBlue }
        if label.contains("Work") { return Color(hex: "A855F7") }
        if motion == "Driving" { return Color.accentAmber }
        return Color.textSecondary
    }
}
