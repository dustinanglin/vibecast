# Brief Splash Design

**Date:** 2026-05-22
**Status:** Approved

## Problem

The full animated splash (~8s) is appropriate on first install but feels long when the app cold-starts after iOS evicts the process. Users have seen the sequence; replaying it in full creates friction on every cold launch.

## Goal

Play the full splash on the very first cold launch (first install). All subsequent cold starts play an abbreviated version: one random vibe hold, then the settle screen, then dismiss (~1.8s total).

## Out of Scope

Updating the full splash intro stage to show the wordmark instead of a blank screen — noted as a future backlog item.

## Approach

**Approach A: `mode` parameter on `SplashView`.** `VibecastApp` owns the persistent flag and passes a `SplashMode` into `SplashView`. `SplashView` stays a pure view — no UserDefaults access inside it.

Rejected alternatives:
- **Separate `BriefSplashView`:** Duplicates the band/wordmark layout, fragile to visual changes.
- **`SplashView` reads UserDefaults itself:** Gives the view a side effect, breaks previews and testability.

## Design

### Persistent flag

`VibecastApp` reads a `UserDefaults` bool key `hasCompletedFirstLaunch`:
- `false` (default, first install) → pass `.full` mode, write `true` when splash completes via `onComplete`
- `true` → pass `.brief` mode

The existing process-lifetime `@State var hasShownSplash` is unchanged — it still prevents the splash from replaying on background→foreground transitions within the same process.

### `SplashMode`

```swift
enum SplashMode {
    case full
    case brief
}
```

Added as a parameter to `SplashView`: `let mode: SplashMode`.

### Brief animation path

In `runAnimation()`, a new branch for `.brief` mode (parallel to the existing `reduceMotion` branch):

1. Pick a random `VibeColorKey` at `SplashView` init: `@State private var briefVibe: VibeColorKey = VibeColorKey.allCases.randomElement()!`
2. Skip intro and cycle stages entirely
3. Set `vibeIndex` to `cycleOrder.firstIndex(of: briefVibe) ?? 0` and transition directly to `.cycle` stage (so the band and content fade in at the random vibe's color)
4. Hold ~800ms
5. Crossfade to `.settle` stage
6. Hold ~1000ms
7. Call `onComplete()`

**Reduce Motion + brief:** Skip directly to settle with the random vibe, hold ~700ms, dismiss. Same pattern as reduce motion + full, just with the random vibe color instead of `.around`.

### Timing summary

| Version | Duration |
|---|---|
| Full | ~8s (unchanged) |
| Brief | ~1.8s |
| Full + reduce motion | ~1.2s (unchanged) |
| Brief + reduce motion | ~0.7s |

### What doesn't change

- Band layout, wordmark, settle copy ("PICK A MOOD · PRESS PLAY" / "Listen with intent.")
- Tap-to-skip (`onTapGesture { onComplete() }`)
- All existing `#Preview` declarations (add a new one for `.brief`)

## Files Changed

- `Vibecast/Views/SplashView.swift` — add `SplashMode`, `mode` parameter, `briefVibe` state, brief branch in `runAnimation()`
- `Vibecast/VibecastApp.swift` — read/write `hasCompletedFirstLaunch` from `UserDefaults`, pass `mode` to `SplashView`

## Testing

- Delete app → reinstall → confirm full splash plays, flag is written
- Force-quit and relaunch → confirm brief splash plays with a (potentially different) random vibe color
- Background → foreground → confirm no splash
- Reduce Motion on → reinstall → confirm static settle fade; force-quit + relaunch → confirm brief reduce-motion path
- Tap to skip works in both modes
