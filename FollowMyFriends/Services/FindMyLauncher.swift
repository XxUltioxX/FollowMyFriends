import Foundation
import AppKit

/// Launches Find My.app and, after a configurable wait, terminates it.
///
/// Opening Find My triggers `findmylocateagent` to perform an immediate server
/// poll, writing fresh locations to the WAL within seconds. Killing it afterward
/// prevents the app from cluttering the Dock.
@MainActor
final class FindMyLauncher {
    private static let bundleIdentifier = "com.apple.findmy"
    private static let appPath = "/System/Applications/FindMy.app"

    var onLog: (@MainActor (String) -> Void)?

    func triggerRefresh(waitSeconds: Int) async {
        log("Launching Find My to trigger location poll…")

        let config = NSWorkspace.OpenConfiguration()
        config.activates = false   // don't steal focus from the user's active app
        config.hides = true        // launch with all windows hidden
        NSWorkspace.shared.openApplication(
            at: URL(fileURLWithPath: Self.appPath),
            configuration: config,
            completionHandler: nil
        )

        // Wait for findmylocateagent to poll and write to WAL
        try? await Task.sleep(for: .seconds(waitSeconds))

        // Return NOW so the caller reads the DB while Find My is still alive.
        // SQLite WAL mode allows concurrent readers — we get a consistent snapshot
        // of all committed frames without racing against an in-progress write.
        //
        // Kill Find My in the background a few seconds later so the UI/Dock
        // isn't cluttered, and FindMy has time to finish any in-progress commit.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            let apps = NSRunningApplication.runningApplications(
                withBundleIdentifier: Self.bundleIdentifier
            )
            apps.forEach { $0.terminate() }
            self?.log("Find My terminated (deferred 3s post-read)")
        }
    }

    private func log(_ msg: String) {
        onLog?(msg)
    }
}
