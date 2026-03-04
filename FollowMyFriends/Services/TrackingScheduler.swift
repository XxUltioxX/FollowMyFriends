import Foundation

/// Drives the periodic polling loop with randomised intervals and night-mode gating.
@MainActor
final class TrackingScheduler {
    var isRunning = false
    var nextPollIn: Int = 0         // seconds until next poll (for UI countdown)
    var lastPollTime: Date?

    var onPoll: (() async -> Void)?

    private var pollTimer: Timer?
    private var countdownTimer: Timer?
    private var settings: AppSettings
    private var lastManualRefresh: Date?

    init(settings: AppSettings) {
        self.settings = settings
    }

    func configure(with settings: AppSettings) {
        self.settings = settings
    }

    // MARK: - Control

    func start() {
        guard !isRunning else { return }
        isRunning = true
        scheduleNext()
    }

    func stop() {
        isRunning = false
        pollTimer?.invalidate()
        pollTimer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    /// Trigger an immediate poll, respecting the manual-refresh throttle.
    func triggerManualPoll() -> Bool {
        if let last = lastManualRefresh,
           Date().timeIntervalSince(last) < Double(settings.manualRefreshThrottleSeconds) {
            return false  // throttled
        }
        lastManualRefresh = Date()
        pollTimer?.invalidate()
        scheduleNext(delay: 0)
        return true
    }

    var secondsUntilManualAllowed: Int {
        guard let last = lastManualRefresh else { return 0 }
        let elapsed = Date().timeIntervalSince(last)
        let remaining = Double(settings.manualRefreshThrottleSeconds) - elapsed
        return max(0, Int(remaining))
    }

    // MARK: - Private

    private func scheduleNext(delay: TimeInterval? = nil) {
        pollTimer?.invalidate()
        let interval = delay ?? randomInterval()
        nextPollIn = Int(interval)

        // One-second countdown tick for the UI
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                if self.nextPollIn > 0 { self.nextPollIn -= 1 }
            }
        }

        pollTimer = Timer.scheduledTimer(withTimeInterval: max(0.01, interval), repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard self.isRunning else { return }
                if self.settings.nightModeEnabled && self.isInNightWindow(Date()) {
                    self.scheduleNext()
                    return
                }
                self.lastPollTime = Date()
                await self.onPoll?()
                if self.isRunning { self.scheduleNext() }
            }
        }
    }

    private func randomInterval() -> TimeInterval {
        guard settings.randomizeInterval else {
            return TimeInterval(settings.pollIntervalMin)
        }
        let lo = settings.pollIntervalMin
        let hi = max(settings.pollIntervalMax, lo + 1)
        return TimeInterval(Int.random(in: lo...hi))
    }

    /// Returns true if `date` falls inside the configured night window.
    private func isInNightWindow(_ date: Date) -> Bool {
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: date)
        let startParts = settings.nightModeStart.split(separator: ":").compactMap { Int($0) }
        let endParts   = settings.nightModeEnd.split(separator: ":").compactMap { Int($0) }

        guard startParts.count == 2, endParts.count == 2,
              let h = comps.hour, let m = comps.minute else { return false }

        let nowMins   = h * 60 + m
        let startMins = startParts[0] * 60 + startParts[1]
        let endMins   = endParts[0] * 60 + endParts[1]

        if startMins > endMins {
            // Crosses midnight (e.g. 23:00 → 07:00)
            return nowMins >= startMins || nowMins < endMins
        } else {
            return nowMins >= startMins && nowMins < endMins
        }
    }
}
