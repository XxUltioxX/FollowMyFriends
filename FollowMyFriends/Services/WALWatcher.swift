import Foundation

/// Watches the SQLite WAL file for writes from findmylocateagent.
///
/// When the system daemon writes new location frames to the WAL, the DispatchSource
/// fires a .write event. We debounce briefly (to let the transaction commit), then
/// call `onWALWritten` so AppState can read the fresh data immediately — without
/// waiting for the next scheduled poll.
final class WALWatcher: @unchecked Sendable {

    private var source: DispatchSourceFileSystemObject?
    private var debounceTask: Task<Void, Never>?

    /// Called on the main queue after a WAL write is detected and debounced.
    var onWALWritten: (() -> Void)?

    // MARK: - Control

    var onLog: ((String) -> Void)?

    func start(walPath: String) {
        stop()

        // O_EVTONLY: open for event-monitoring only, does not prevent deletion
        let fd = open(walPath, O_EVTONLY)
        guard fd >= 0 else {
            let err = String(cString: strerror(errno))
            onLog?("WAL watcher FAILED to open \(walPath): \(err) (errno=\(errno))")
            return
        }
        onLog?("WAL watcher opened fd=\(fd) watching: \(walPath)")

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: .main
        )

        src.setEventHandler { [weak self] in
            guard let self else { return }
            // findmylocateagent writes many frames per transaction.
            // Debounce: cancel any pending read and restart the 2s timer.
            self.debounceTask?.cancel()
            self.debounceTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                self.onLog?("WAL updated — reading fresh data…")
                self.onWALWritten?()
            }
        }
        src.setCancelHandler { close(fd) }
        src.resume()
        source = src
    }

    func stop() {
        debounceTask?.cancel()
        debounceTask = nil
        source?.cancel()
        source = nil
    }
}
