# Resume Context — Vibecast

Snapshot for reopening Claude on this project after a model update. Mirrors the pattern of `2026-05-18-launch-restart-context.md`.

## TL;DR

**V1.0.0 launched on the App Store 2026-05-22.** V1.0.1 (build 20) was built and uploaded to TestFlight 2026-05-23 with the brief-splash feature. No repo activity since then — working tree clean, `main` = `origin/main` at `696cf99`.

Unknown at time of writing: whether 1.0.1 was submitted for App Store review after TestFlight, or is still TestFlight-only. Check App Store Connect on resume.

## What shipped in 1.0.1 (post-launch)

**Brief splash** — first cold launch after install plays the full ~8s vibe cycle. Every subsequent cold start plays an abbreviated ~1.8s splash: one random vibe hold → crossfade to settle → dismiss. Background→foreground still skips the splash entirely (unchanged process-lifetime gate).

Implementation:
- `SplashMode` enum (`.full` / `.brief`) added to `SplashView.swift`
- `VibecastApp.hasCompletedFirstLaunchKey` UserDefaults flag written on splash completion
- `VibecastApp.splashMode(defaults:)` static factory, unit-tested
- Brief timings extracted to `briefVibeHoldMs` (800) and `briefSettleHoldMs` (1000)
- Reduce Motion honored in both modes

Spec: `docs/superpowers/specs/2026-05-22-brief-splash-design.md`
Plan: `docs/superpowers/plans/2026-05-22-brief-splash.md`

## Public infrastructure (unchanged from launch)

- Domain: `vibecastplayer.app` — Cloudflare proxy, Full SSL, GitHub Pages origin
- Privacy: `https://vibecastplayer.app/privacy.html`
- Support: `https://vibecastplayer.app/support.html`
- Support email: `support@vibecastplayer.app` → personal
- iCloud Shortcut (Vibecast Import): `https://www.icloud.com/shortcuts/edfe11df98fc418094340da723418f6e` — baked into `ApplePodcastsImportWizard.iCloudShortcutInstallURL`. Don't republish without updating that constant.

## Repo state

- Branch: `main`, up to date with `origin/main` at `696cf99`
- Working tree: clean except two long-standing untracked notes (`2026-05-17-app-store-listing-copy.md`, `2026-05-18-launch-restart-context.md`) — safe to `git add` if you want them tracked
- Marketing version in project: `1.0.1`
- `TARGETED_DEVICE_FAMILY = "1"` (iPhone-only)
- Worktree convention: `.worktrees/` (gitignored). Use `git worktree add .worktrees/<feature>` for new work

## TestFlight / release notes

- Fastlane lane: `bundle exec fastlane beta` — builds, archives, uploads to TestFlight
- CI workflow: `.github/workflows/testflight.yml` — triggers on push to `main`
- 1.0.1 build 20 was uploaded manually via local `fastlane beta` on 2026-05-23 (bypassed CI); `main` was pushed to origin after the fact so history is synced
- Gotcha to remember: once a version is App Store-approved, that train (e.g. `1.0`) closes for new TestFlight builds. Bump `MARKETING_VERSION` for every new build cycle

## Open follow-ups (pre-launch backlog, still applicable)

- **`#126`** — vibe-color mini-player + full-screen player controls (Plan 7 followup)
- **`#137`** — Apple Podcasts wizard polish (VoiceOver labels, font hierarchy, timer freshness)
- **`#138`** — Audit `importFeeds` succeeded-counter accuracy (defer until real mismatch surfaces)
- **`#140`** — iCloud sync for subscriptions + playback state (v1.1+)

## Backlog (not ticketed)

- **CarPlay support** — entitlement applied for; own brainstorm+plan when granted. 1-2 day project
- **Search-result detail page** — preview-mode `PodcastDetailView` for iTunes search hits, with Subscribe button. Beta-tester request
- **Plan 8: Pinning** — Phase 3 of the design handoff, deferred pre-launch
- **Fastlane Snapshot** — automate screenshot capture for release cycles
- **Full-splash intro polish** — replace the initial blank-screen fade with a wordmark that transitions into the vibe cycle (raised during the brief-splash brainstorm)

## Quick verification on resume

```bash
# Confirm clean, synced repo
git -C /Users/dustinanglin/Projects/Vibecast status
git -C /Users/dustinanglin/Projects/Vibecast log --oneline -5

# Confirm live URLs still serve
curl -sI https://vibecastplayer.app/privacy.html | head -1   # expect HTTP/2 200
curl -sI https://vibecastplayer.app/support.html | head -1   # expect HTTP/2 200

# App Store / TestFlight state: check email or App Store Connect web UI —
# no gh CLI equivalent for review state.
```

## How to brief Claude on resume

> Vibecast V1.0.0 has been live on the App Store since 2026-05-22. V1.0.1 (brief-splash feature) was uploaded to TestFlight on 2026-05-23 but no work has happened since. Read `docs/superpowers/notes/2026-07-14-resume-context.md` for the snapshot.
