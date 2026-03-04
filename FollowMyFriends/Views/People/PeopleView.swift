import SwiftUI

struct PeopleView: View {
    @Environment(AppState.self) private var appState
    @State private var isScanning = false

    private var untracked: [String] {
        appState.availableIdentifiers.filter { id in
            !appState.trackedPeople.contains(where: { $0.identifier == id })
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ────────────────────────────────────────────────────
            HStack {
                Text("People")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Button {
                    isScanning = true
                    appState.scanDatabase()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isScanning = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isScanning {
                            ProgressView().scaleEffect(0.6).frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .medium))
                        }
                        Text("Rescan Database")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.elevated)
                    .foregroundStyle(Color.textPrimary)
                    .cornerRadius(7)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.borderFocus, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isScanning)
            }
            .padding(.horizontal, 20)
            .frame(height: 56)
            .overlay(alignment: .bottom) { Divider().background(Color.border) }

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // ── Available (not yet tracked) ───────────────────────
                    if !untracked.isEmpty {
                        SectionHeader(title: "Available", subtitle: "\(untracked.count) from Find My")
                        VStack(spacing: 2) {
                            ForEach(untracked, id: \.self) { id in
                                AvailableRow(identifier: id) {
                                    appState.addPerson(identifier: id)
                                }
                            }
                        }
                        .background(Color.surface)
                        .cornerRadius(10)
                    }

                    // ── Tracked ───────────────────────────────────────────
                    SectionHeader(
                        title: "Tracked",
                        subtitle: "\(appState.trackedPeople.count) people"
                    )

                    if appState.trackedPeople.isEmpty {
                        EmptyPeopleState()
                    } else {
                        VStack(spacing: 2) {
                            ForEach(appState.trackedPeople) { person in
                                PeopleRow(person: person)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .overlay(alignment: .bottom) {
                                        if person.id != appState.trackedPeople.last?.id {
                                            Divider()
                                                .background(Color.border)
                                                .padding(.leading, 14)
                                        }
                                    }
                            }
                        }
                        .background(Color.surface)
                        .cornerRadius(10)
                    }
                }
                .padding(16)
            }
        }
    }
}

// MARK: - Section Header

private struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.textTertiary)
                .textCase(.uppercase)
                .tracking(0.6)
            Spacer()
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Available Row

private struct AvailableRow: View {
    let identifier: String
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(Color.accentGreen)
                .font(.system(size: 16))
                .onTapGesture { onAdd() }

            Text(identifier)
                .font(.system(size: 13).monospaced())
                .foregroundStyle(Color.textSecondary)

            Spacer()

            Button("Add") { onAdd() }
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.accentGreen.opacity(0.12))
                .foregroundStyle(Color.accentGreen)
                .cornerRadius(5)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Divider().background(Color.border).padding(.leading, 14)
        }
    }
}

// MARK: - Empty State

private struct EmptyPeopleState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 36))
                .foregroundStyle(Color.textTertiary)
                .padding(.top, 32)
            Text("No tracked people")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.textSecondary)
            Text("Scan the database to discover friends\nfrom your Find My network.")
                .font(.system(size: 11))
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity)
        .background(Color.surface)
        .cornerRadius(10)
    }
}
