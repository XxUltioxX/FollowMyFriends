import Foundation
import UserNotifications

/// Sends macOS notifications when a person arrives at or departs from a location.
@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private var previousLabels: [String: String] = [:]

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Compare new location label against cached value and fire a notification if it changed.
    func checkArrivalDeparture(person: TrackedPerson, newLocation: LocationUpdate) {
        let key = person.identifier
        let newLabel = newLocation.displayLabel
        defer { previousLabels[key] = newLabel }

        guard let oldLabel = previousLabels[key], oldLabel != newLabel else { return }

        let title: String
        let body: String

        if newLocation.isHome {
            title = "\(person.displayName) arrived at Home 🏠"
            body  = "Previously at: \(oldLabel)"
        } else {
            title = "\(person.displayName) left \(oldLabel)"
            body  = "Now at: \(newLabel)"
        }

        fire(title: title, body: body)
    }

    private func fire(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default

        let req = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }
}
