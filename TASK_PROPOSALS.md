# Codebase Task Proposals

## 1) Typo Fix Task
**Issue found:** README uses mixed spelling (`colours`) while the rest of UI/docs predominantly use US English (`Color`, `color-coded`).

**Proposed task:** Replace `assign avatar colours` with `assign avatar colors` in the People screenshot caption for consistency.

**Where:** `README.md` screenshot caption under **People Management**.

---

## 2) Bug Fix Task
**Issue found:** `TrackingScheduler.randomInterval()` can schedule one second above the configured max when min == max because it sets:
- `hi = max(pollIntervalMax, lo + 1)`
- then picks `Int.random(in: lo...hi)`

For example, min=600 and max=600 can result in 601.

**Proposed task:** Clamp and normalize bounds so random selection never exceeds user-configured max. Suggested behavior:
- If randomization is off: use `pollIntervalMin`
- If randomization is on and `max <= min`: use `min`
- Else random in `min...max`

**Where:** `FollowMyFriends/Services/TrackingScheduler.swift` in `randomInterval()`.

---

## 3) Code Comment / Documentation Discrepancy Task
**Issue found:** The app still logs and comments that key verification requires **Full Disk Access**, but README says the app works via folder-based user-intent access without Full Disk Access.

**Proposed task:** Update the in-code comments/log guidance to match the current access model (bookmark/folder grant path) or adjust README if Full Disk Access is still required in specific flows.

**Where:**
- `FollowMyFriends/ViewModels/AppState.swift` comments/logs around key verification error handling.
- `README.md` section **🔑 Permissions Without Full Disk Access**.

---

## 4) Test Improvement Task
**Issue found:** No dedicated test target/files are present for scheduler edge cases.

**Proposed task:** Add unit tests for `TrackingScheduler` interval and night-window logic:
- `randomInterval()` never exceeds configured max
- `min == max` returns exactly that value
- Night window crossing midnight vs same-day windows
- Manual refresh throttle countdown behavior

**Where:** Add a new test target (e.g., `FollowMyFriendsTests`) and `TrackingSchedulerTests.swift`.
