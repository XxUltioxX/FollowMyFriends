import Foundation
import SwiftUI

struct LogEntry: Identifiable, Sendable {
    var id: UUID = UUID()
    var timestamp: Date
    var level: Level
    var message: String

    enum Level: String, CaseIterable, Sendable {
        case info   = "INFO"
        case warn   = "WARN"
        case error  = "ERROR"
        case mqtt   = "MQTT"
        case findmy = "FINDMY"

        var color: Color {
            switch self {
            case .info:   return Color(hex: "3B82F6")   // blue
            case .warn:   return Color(hex: "F59E0B")   // amber
            case .error:  return Color(hex: "EF4444")   // red
            case .mqtt:   return Color(hex: "A855F7")   // purple
            case .findmy: return Color(hex: "22C55E")   // green
            }
        }

        var badge: String { rawValue }
    }

    var formattedTime: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        return fmt.string(from: timestamp)
    }
}
