import Foundation
import ServiceManagement

/// Manages the macOS login-item registration via SMAppService (macOS 13+).
struct LoginItemService: Sendable {
    static var isRegistered: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    @MainActor
    static func setEnabled(_ enabled: Bool) throws {
        if #available(macOS 13.0, *) {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        }
    }
}
