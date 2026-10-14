# Resume Context — Vibecast (pre-macOS-upgrade snapshot)

Snapshot taken 2026-10-13 before a macOS upgrade. Supersedes `2026-07-14-resume-context.md`.

## TL;DR

**V1.0.0 live on the App Store since 2026-05-22.** **V1.0.2 (episode downloads) uploaded to TestFlight 2026-07-16** via CI. No repo activity since — `main` = `origin/main` at `5b79e2f`, working tree clean, no feature branches or worktrees outstanding.

**Check on resume:** whether 1.0.2 was ever submitted to the App Store or is still TestFlight-only (App Store Connect web UI / email — no CLI for this). If still TestFlight-only, submitting 1.0.2 as the first public update (downloads + brief splash together) is the obvious next move.

## Released versions

| Version | State | Date |
|---|---|---|
| 1.0.0 | Live on App Store | 2026-05-22 |
| 1.0.1 (brief splash) | TestFlight | 2026-05-23 |
| 1.0.2 (episode downloads) | TestFlight | 2026-07-16 |

**Version rule:** once a version is App Store-approved its train closes for new builds — bump `MARKETING_VERSION` (4 occurrences in `Vibecast/Vibecast.xcodeproj/project.pbxproj`) for every post-release cycle.

## What shipped in 1.0.2 (episode downloads)

Auto-download newest-per-show on foreground refresh; keep-last-N pruning (default 3, manual downloads exempt); download swipe actions + state badges on both the episode lists and the library/vibes cards; download-settings sheet (masthead gear): auto-download, keep-N, delete-when-played, wifi-only, storage summary + delete-all; offline playback from Application Support with self-heal fallback to streaming; background `URLSession` so in-flight downloads survive backgrounding; unsubscribe releases a show's downloaded files.

Key files: `Vibecast/Vibecast/Downloads/` (Manager/Store/Policy/Settings), `AppDelegate.swift` (background-session completion hook only).
Spec: `docs/superpowers/specs/2026-07-14-episode-downloads-design.md`
Plan: `docs/superpowers/plans/2026-07-14-episode-downloads.md`
All verified on-device 2026-07-15/16 (airplane-mode playback acceptance test passed). Test suite: 178 cases green at ship time.

## Release pipeline gotchas (hard-won)

- **TestFlight CI** (`.github/workflows/testflight.yml`) auto-triggers on pushes to `main` touching `Vibecast/**`, `fastlane/**`, or `Gemfile*` — docs-only pushes don't trigger. Don't also run `bundle exec fastlane beta` locally or you get duplicate builds. Manual trigger available via workflow_dispatch.
- **Apple Developer Program License Agreement expiry** blocks ALL App Store Connect API calls with "A required agreement is missing or has expired" — account holder accepts at developer.apple.com / App Store Connect, propagation takes a few minutes, then `gh run rerun <id> --failed`.
- Fastlane auth: App Store Connect API key env vars; local `.p8` lives outside the repo (`~/.appstoreconnect/`). CI materialises it from a base64 GitHub secret.

## macOS-upgrade sensitivities (why this snapshot exists)

- Toolchain at ship time: Xcode 26.4.1, iPhone 17 simulators, test destination `platform=iOS Simulator,name=iPhone 17`. After upgrade, verify: `xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination "platform=iOS Simulator,name=iPhone 17"` → expect 178 passing.
- Local signing is managed by match (`vibecast-certs` repo); if keychain state is disturbed by the upgrade, `bundle exec fastlane setup_certs` restores it (CI is unaffected — it uses ephemeral keychains).
- `~/.appstoreconnect/AuthKey_*.p8` and `~/.claude/` memory dir live in the home folder — survive an in-place upgrade, but worth confirming after.
- Ruby/bundler: `vendor/` is gitignored and vendored per-machine; expect `bundle install` to need a re-run if the system Ruby changes.

## Public infrastructure (unchanged)

- `vibecastplayer.app` — Cloudflare proxy, Full SSL, GitHub Pages origin; `/privacy.html`, `/support.html` live
- `support@vibecastplayer.app` → personal address
- iCloud Shortcut (Vibecast Import): `https://www.icloud.com/shortcuts/edfe11df98fc418094340da723418f6e` — baked into `ApplePodcastsImportWizard.iCloudShortcutInstallURL`; don't republish without updating that constant

## Backlog on resume

Post-trip cleanup ticket (minor review findings from the downloads build): `store()` overwrite/throws test coverage; `try? modelContext.save()` swallowing throughout; progress-dict Task-ordering races; settings storage number stales while sheet open; failed-badge tap-to-retry (swipe-only today); `nonisolated` sweep ahead of any Swift 6 migration.

Feature backlog (unchanged): #126 vibe-color mini-player + full-screen player; #137 import-wizard polish; #138 importFeeds counter audit; #140 iCloud sync (v1.1+); CarPlay (entitlement was pending); search-result detail page; Plan 8 Pinning; Fastlane Snapshot; full-splash wordmark intro polish.

## Quick verification on resume

```bash
git -C /Users/dustinanglin/Projects/Vibecast status          # clean, main @ 5b79e2f or later
git -C /Users/dustinanglin/Projects/Vibecast log --oneline -5
xcodebuild -version                                          # confirm Xcode still present post-upgrade
curl -sI https://vibecastplayer.app/privacy.html | head -1   # expect HTTP/2 200
gh run list --repo dustinanglin/vibecast --workflow testflight.yml --limit 3
```

## How to brief Claude on resume

> Vibecast 1.0.2 (episode downloads) has been on TestFlight since 2026-07-16; 1.0.0 is live on the App Store. I just upgraded macOS. Read `docs/superpowers/notes/2026-10-13-resume-context.md` for the snapshot, run the verification commands, and check whether 1.0.2 ever went to App Store review.
