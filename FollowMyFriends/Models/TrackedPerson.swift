import Foundation
import SwiftUI

struct TrackedPerson: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var name: String
    var identifier: String  // phone number or email
    var avatarColorName: String
    var isActive: Bool

    // Runtime state — not persisted (populated from DB at runtime)
    var lastLocation: LocationUpdate?

    var displayName: String {
        name.isEmpty ? identifier : name
    }

    var initials: String {
        let words = displayName.split(separator: " ")
        if words.count >= 2 {
            return (String(words[0].prefix(1)) + String(words[1].prefix(1))).uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }

    var avatarColor: Color {
        switch avatarColorName {
        case "blue":   return Color(hex: "3B82F6")
        case "pink":   return Color(hex: "EC4899")
        case "green":  return Color(hex: "22C55E")
        case "purple": return Color(hex: "A855F7")
        case "orange": return Color(hex: "F97316")
        case "red":    return Color(hex: "EF4444")
        default:       return Color(hex: "3B82F6")
        }
    }

    var isOnline: Bool {
        lastLocation != nil  // we have coordinates from the DB
    }

    enum CodingKeys: String, CodingKey {
        case id, name, identifier, avatarColorName, isActive
    }

    init(
        id: UUID = UUID(),
        name: String = "",
        identifier: String,
        avatarColorName: String = "blue",
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.identifier = identifier
        self.avatarColorName = avatarColorName
        self.isActive = isActive
    }

    static func == (lhs: TrackedPerson, rhs: TrackedPerson) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.identifier == rhs.identifier &&
        lhs.avatarColorName == rhs.avatarColorName &&
        lhs.isActive == rhs.isActive &&
        lhs.lastLocation == rhs.lastLocation
    }
}
