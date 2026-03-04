import SwiftUI

struct PeopleRow: View {
    let person: TrackedPerson
    @Environment(AppState.self) private var appState
    @State private var editedName: String = ""
    @State private var showDeleteConfirm = false

    private let colorPalette = ["blue", "pink", "green", "purple", "orange", "red"]

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            AvatarView(person: person)
                .frame(width: 36, height: 36)
                .scaleEffect(36.0 / 46.0)

            VStack(alignment: .leading, spacing: 3) {
                // Name field
                TextField("Add display name…", text: $editedName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                    .textFieldStyle(.plain)
                    .onSubmit { commitName() }
                    .onAppear { editedName = person.name }
                    .onChange(of: person.name) { _, new in editedName = new }

                // Identifier
                Text(person.identifier)
                    .font(.system(size: 11).monospaced())
                    .foregroundStyle(Color.textTertiary)
            }

            Spacer()

            // Color picker
            HStack(spacing: 4) {
                ForEach(colorPalette, id: \.self) { colorName in
                    Circle()
                        .fill(colorForName(colorName))
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.8), lineWidth: 1.5)
                                .opacity(person.avatarColorName == colorName ? 1 : 0)
                        )
                        .onTapGesture {
                            var updated = person
                            updated.avatarColorName = colorName
                            appState.updatePerson(updated)
                        }
                }
            }

            // Active toggle
            Toggle("", isOn: Binding(
                get: { person.isActive },
                set: { val in
                    var updated = person
                    updated.isActive = val
                    appState.updatePerson(updated)
                }
            ))
            .toggleStyle(.switch)
            .scaleEffect(0.75)

            // Delete button
            Button {
                showDeleteConfirm = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
            }
            .buttonStyle(.plain)
            .confirmationDialog(
                "Remove \(person.displayName)?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) {
                    appState.removePerson(id: person.id)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will stop tracking \(person.displayName) and remove their MQTT entity.")
            }
        }
    }

    private func commitName() {
        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != person.name else { return }
        var updated = person
        updated.name = trimmed
        appState.updatePerson(updated)
    }

    private func colorForName(_ name: String) -> Color {
        switch name {
        case "blue":   return Color(hex: "3B82F6")
        case "pink":   return Color(hex: "EC4899")
        case "green":  return Color(hex: "22C55E")
        case "purple": return Color(hex: "A855F7")
        case "orange": return Color(hex: "F97316")
        case "red":    return Color(hex: "EF4444")
        default:       return Color(hex: "3B82F6")
        }
    }
}
