import Foundation

struct LocationUpdate: Equatable, Sendable {
    var latitude: Double
    var longitude: Double
    var horizontalAccuracy: Double
    var verticalAccuracy: Double
    var altitude: Double
    var speed: Double           // m/s, -1 = unknown
    var course: Double          // degrees, -1 = unknown
    var timestamp: Date
    var motionActivityState: Int  // 0 = stationary, 1 = moving
    var publishReason: Int
    var locationLabel: String     // e.g. "_$!<home>!$_", "Parents House", ""
    var findMyId: String

    // MARK: - Derived Properties

    var isHome: Bool {
        locationLabel.lowercased().contains("home") ||
        locationLabel == "_$!<home>!$_"
    }

    var isDriving: Bool {
        speed > 5 || locationLabel.lowercased().contains("driv")
    }

    var motionStateDescription: String {
        if isDriving { return "Driving" }
        return motionActivityState == 0 ? "Stationary" : "Moving"
    }

    var displayLabel: String {
        switch locationLabel {
        case "_$!<home>!$_": return "Home 🏠"
        case "_$!<work>!$_": return "Work 💼"
        case "": return "Unknown"
        default: return locationLabel
        }
    }

    /// Human-readable "X min ago" helper (used in detail panel)
    var relativeTime: String {
        let secs = Int(Date().timeIntervalSince(timestamp))
        if secs < 60 { return "Just now" }
        if secs < 3600 { return "\(secs / 60) min ago" }
        if secs < 86400 { return "\(secs / 3600)h ago" }
        return "\(secs / 86400)d ago"
    }

    var haState: String {
        isHome ? "home" : "not_home"
    }
}
