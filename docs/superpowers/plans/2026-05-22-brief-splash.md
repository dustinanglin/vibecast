# Brief Splash Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Play the full animated splash only on first install; play an abbreviated single-vibe splash (~1.8s) on all subsequent cold starts.

**Architecture:** Add `SplashMode` enum to `SplashView.swift`; pass `mode` from `VibecastApp`, which reads/writes a `UserDefaults` bool (`hasCompletedFirstLaunch`) to distinguish first vs. subsequent cold starts. A static `splashMode(defaults:)` helper on `VibecastApp` keeps the flag logic testable.

**Tech Stack:** SwiftUI, SwiftData, XCTest, UserDefaults

---

## Files

| Action | Path | Responsibility |
|--------|------|----------------|
| Modify | `Vibecast/Vibecast/Views/SplashView.swift` | Add `SplashMode` enum, `mode` parameter, `briefVibe` state, brief animation branch, updated previews |
| Modify | `Vibecast/Vibecast/VibecastApp.swift` | Add `hasCompletedFirstLaunchKey`, `splashMode(defaults:)` helper, wire flag read/write and mode into `SplashView` call |
| Create | `Vibecast/VibecastTests/SplashModeTests.swift` | Unit tests for mode-selection logic |

---

## Task 1: Write failing tests for mode-selection logic

**Files:**
- Create: `Vibecast/VibecastTests/SplashModeTests.swift`

- [ ] **Step 1: Create the test file**

```swift
import XCTest
@testable import Vibecast

final class SplashModeTests: XCTestCase {

    func test_splashMode_returnsFullWhenFlagAbsent() {
        let suiteName = "test.splash.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        XCTAssertEqual(VibecastApp.splashMode(defaults: defaults), .full)
    }

    func test_splashMode_returnsBriefWhenFlagSet() {
        let suiteName = "test.splash.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(true, forKey: VibecastApp.hasCompletedFirstLaunchKey)
        XCTAssertEqual(VibecastApp.splashMode(defaults: defaults), .brief)
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

```bash
xcodebuild test \
  -project Vibecast/Vibecast.xcodeproj \
  -scheme Vibecast \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -only-testing:VibecastTests/SplashModeTests \
  2>&1 | grep -E "(error:|Build FAILED)"
```

Expected: compile errors — `SplashMode` not defined, `VibecastApp.splashMode` not defined, `VibecastApp.hasCompletedFirstLaunchKey` not defined.

---

## Task 2: Add `SplashMode` enum and `VibecastApp` helpers

**Files:**
- Modify: `Vibecast/Vibecast/Views/SplashView.swift`
- Modify: `Vibecast/Vibecast/VibecastApp.swift`

- [ ] **Step 1: Add `SplashMode` to `SplashView.swift`**

Add this block directly above the `struct SplashView` declaration:

```swift
enum SplashMode: Equatable {
    case full
    case brief
}
```

Then add `mode` as the first stored property of `SplashView` (before `onComplete`), giving it a default value so existing call sites in `VibecastApp` keep compiling until Task 3 updates them:

```swift
struct SplashView: View {
    let mode: SplashMode = .full
    let onComplete: () -> Void
    // ... rest unchanged
```

Update the existing `#Preview` at the bottom of the file:

```swift
#Preview("Full") {
    SplashView(mode: .full) {}
}
```

- [ ] **Step 2: Add helpers to `VibecastApp.swift`**

Add these two declarations inside `VibecastApp`, after the existing `@State private var hasShownSplash` line:

```swift
static let hasCompletedFirstLaunchKey = "hasCompletedFirstLaunch"

static func splashMode(defaults: UserDefaults = .standard) -> SplashMode {
    defaults.bool(forKey: hasCompletedFirstLaunchKey) ? .brief : .full
}
```

- [ ] **Step 3: Run tests — expect pass**

```bash
xcodebuild test \
  -project Vibecast/Vibecast.xcodeproj \
  -scheme Vibecast \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -only-testing:VibecastTests/SplashModeTests \
  2>&1 | grep -E "(Test Case|PASSED|FAILED|Build)"
```

Expected:
```
Test Case '-[VibecastTests.SplashModeTests test_splashMode_returnsFullWhenFlagAbsent]' passed
Test Case '-[VibecastTests.SplashModeTests test_splashMode_returnsBriefWhenFlagSet]' passed
```

- [ ] **Step 4: Commit**

```bash
git add Vibecast/Vibecast/Views/SplashView.swift \
        Vibecast/Vibecast/VibecastApp.swift \
        Vibecast/VibecastTests/SplashModeTests.swift
git commit -m "feat(splash): add SplashMode enum and splashMode() logic with tests"
```

---

## Task 3: Wire `splashMode` into `VibecastApp` body

**Files:**
- Modify: `Vibecast/Vibecast/VibecastApp.swift`

- [ ] **Step 1: Add `splashMode` state property**

Add this line directly below `@State private var hasShownSplash: Bool = false`:

```swift
@State private var splashMode: SplashMode = VibecastApp.splashMode()
```

- [ ] **Step 2: Update the `SplashView` call in `body`**

Replace the existing `SplashView { ... }` block:

```swift
// Before:
if !hasShownSplash {
    SplashView {
        withAnimation(.easeInOut(duration: 0.45)) {
            hasShownSplash = true
        }
    }
    .transition(.opacity)
}
```

```swift
// After:
if !hasShownSplash {
    SplashView(mode: splashMode) {
        UserDefaults.standard.set(true, forKey: VibecastApp.hasCompletedFirstLaunchKey)
        withAnimation(.easeInOut(duration: 0.45)) {
            hasShownSplash = true
        }
    }
    .transition(.opacity)
}
```

- [ ] **Step 3: Build to verify no errors**

```bash
xcodebuild build \
  -project Vibecast/Vibecast.xcodeproj \
  -scheme Vibecast \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  2>&1 | grep -E "(error:|Build succeeded|Build FAILED)"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Vibecast/Vibecast/VibecastApp.swift
git commit -m "feat(splash): wire UserDefaults first-launch flag into SplashView mode"
```

---

## Task 4: Implement brief animation path in `SplashView`

**Files:**
- Modify: `Vibecast/Vibecast/Views/SplashView.swift`

- [ ] **Step 1: Add `briefVibe` state property**

Add this line below the existing `@State private var vibeIndex: Int = 0`:

```swift
@State private var briefVibe: VibeColorKey = VibeColorKey.allCases.randomElement()!
```

- [ ] **Step 2: Replace `runAnimation()` with the branched version**

Replace the entire `runAnimation()` function:

```swift
@MainActor
private func runAnimation() async {
    if reduceMotion {
        withAnimation { stage = .settle }
        try? await Task.sleep(for: .milliseconds(mode == .brief ? 700 : Self.reduceMotionHoldMs))
        onComplete()
        return
    }

    if mode == .brief {
        vibeIndex = Self.cycleOrder.firstIndex(of: briefVibe) ?? 0
        withAnimation { stage = .cycle }
        try? await Task.sleep(for: .milliseconds(800))
        withAnimation { stage = .settle }
        try? await Task.sleep(for: .milliseconds(1_000))
        onComplete()
        return
    }

    // Full animation (unchanged below)
    try? await Task.sleep(for: .milliseconds(Self.introDurationMs))
    withAnimation { stage = .cycle }

    for index in 1..<Self.cycleOrder.count {
        try? await Task.sleep(for: .milliseconds(Self.cycleHoldMs))
        withAnimation { vibeIndex = index }
    }

    try? await Task.sleep(for: .milliseconds(Self.cycleHoldMs))
    withAnimation { stage = .settle }

    try? await Task.sleep(for: .milliseconds(Self.settleHoldMs))
    onComplete()
}
```

- [ ] **Step 3: Add brief preview**

Add a second preview below the existing one at the bottom of the file:

```swift
#Preview("Brief") {
    SplashView(mode: .brief) {}
}
```

- [ ] **Step 4: Build and run all tests**

```bash
xcodebuild test \
  -project Vibecast/Vibecast.xcodeproj \
  -scheme Vibecast \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  2>&1 | grep -E "(Test Suite|PASSED|FAILED|Build)"
```

Expected: all tests pass, build succeeds.

- [ ] **Step 5: Commit**

```bash
git add Vibecast/Vibecast/Views/SplashView.swift
git commit -m "feat(splash): implement brief cold-start splash — random vibe hold then settle"
```

---

## Task 5: Manual verification + TestFlight build

- [ ] **Step 1: Verify first-install flow**

On simulator or device: delete the app, install fresh build, launch.
Expected: full ~8s splash plays (morning → around → workout → winddown → deepwork → settle → dismiss).

- [ ] **Step 2: Verify brief flow**

Force-quit the app (swipe up from app switcher), relaunch.
Expected: a single random vibe band + name + tagline appears briefly (~800ms), crossfades to "PICK A MOOD · PRESS PLAY" / "Listen with intent." settle (~1000ms), then dismisses. Vibe color may differ between relaunches.

- [ ] **Step 3: Verify no splash on background→foreground**

Background the app (home button / swipe up to home), return to it.
Expected: no splash, goes straight to the subscriptions list.

- [ ] **Step 4: Verify tap-to-skip still works**

In both modes: tap anywhere during the splash.
Expected: dismisses immediately.

- [ ] **Step 5: Push TestFlight build**

```bash
bundle exec fastlane beta
```

Expected: build uploads successfully and appears in TestFlight within a few minutes.
