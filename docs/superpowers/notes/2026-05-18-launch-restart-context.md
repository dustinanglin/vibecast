# Restart Context — Vibecast V1 Launch

Snapshot of where we are right before the laptop restart. Use this as the briefing when you fire Claude back up.

## TL;DR

**V1.0.0 submitted to App Store Connect on 2026-05-17.** Awaiting Apple Review. Average review cycle is 24-48 hours. No action needed until Apple responds.

## What shipped in V1

- The full Vibecast app — subscriptions, vibes, audio playback, splash screen, Apple Podcasts → Vibecast import wizard, per-podcast episode sort, VoiceOver time labels, contextual played/unplayed swipe.
- iPhone-only target (`TARGETED_DEVICE_FAMILY = "1"`) — fixed at the last minute when App Store Connect required iPad screenshots.
- Marketing version `1.0.0`, build number set by TestFlight CI.
- Final v1 commit: `f7d55c8` ("iPhone-only target — drop iPad from device family").
- Branch: `main` on `origin/main`. Working tree should be clean.

## Public infrastructure (all live)

- **Custom domain:** `vibecastplayer.app` — owned by you, DNS via Cloudflare, Universal SSL cert serving via Cloudflare proxy (orange-cloud / Full SSL mode). GitHub Pages remains the origin.
- **Privacy:** `https://vibecastplayer.app/privacy.html`
- **Support:** `https://vibecastplayer.app/support.html`
- **Landing:** `https://vibecastplayer.app/`
- **Support email:** `support@vibecastplayer.app` (forwards to your personal address)
- **Shortcut iCloud URL** (Vibecast Import): `https://www.icloud.com/shortcuts/edfe11df98fc418094340da723418f6e` — baked into `ApplePodcastsImportWizard.iCloudShortcutInstallURL`. Don't republish without updating that constant.

## App Store listing copy

Lives in `docs/superpowers/notes/2026-05-17-app-store-listing-copy.md`. Reference for any post-submission edits or future versions.

## Background tasks that go away on restart

We had a scheduled wakeup polling the Let's Encrypt cert (which never issued — that's why we flipped to Cloudflare proxy). Those wakeup hooks reset on session restart. If for any reason you ever switch back to grey-cloud (DNS-only), Let's Encrypt would need to retry — but you don't need to think about that unless something changes.

## Open follow-ups (in TaskCreate list, all pending)

- `#126` — Plan 7 followup: vibe-color mini-player + full-screen player controls
- `#137` — Apple Podcasts wizard polish (VoiceOver labels, font hierarchy, timer-driven freshness)
- `#138` — Audit `importFeeds` succeeded-counter accuracy (currently uses fetchCount delta; could read `failedSubscribes` instead — defer until manual import sees a real mismatch)
- `#140` — iCloud sync for subscriptions + playback state (v1.1+)

## Backlog items raised but not yet ticketed

- **CarPlay support** — you applied for the entitlement; waiting on Apple. Once granted, this is its own brainstorm + plan (CPTemplateApplicationSceneDelegate, CPListTemplate hierarchy, manual sim verification). 1-2 day project.
- **Search-result detail page** (beta-tester request #3) — preview-mode `PodcastDetailView` showing iTunes metadata + RSS-fetched episodes for a search result, with a Subscribe button. Real feature, V1.1 candidate.
- **Plan 8: Pinning** — Phase 3 of the design handoff. Was the original next step pre-launch but explicitly deferred until after v1.
- **Fastlane Snapshot setup** — automate screenshot capture for v1.1+ releases so you don't redo ⌘S × 5 every cycle.

## What happens when Apple responds

**If approved:**
- App Store Connect notifies you via email.
- App goes live at the time you specified (default: as soon as approved).
- Pricing → Free. Available in all countries.
- TestFlight build continues working in parallel.

**If rejected:**
- Apple sends a rejection reason — usually one of: privacy disclosure mismatch, missing/wrong screenshots, an "unrestricted web access" concern, or a metadata issue.
- We address whatever they flagged, push a fix, re-submit. The submission queue resets to ~24-48 hour review again on a new submission, but minor metadata-only fixes typically come back faster.
- Most common gotchas for podcast players:
  - Reviewer can't find a way to test → we already covered this in App Review Notes.
  - "Doesn't do enough" claim → very rare for a focused player.

## Quick verification commands on restart

```bash
# Check you're on main and clean
git -C /Users/dustinanglin/Projects/Vibecast status

# Check live URLs still serve
curl -sI https://vibecastplayer.app/privacy.html | head -1   # expect HTTP/2 200
curl -sI https://vibecastplayer.app/support.html | head -1   # expect HTTP/2 200

# Check App Store Connect via gh CLI (if you want to check programmatically):
# Apple doesn't expose review state via the gh CLI; check email or
# App Store Connect web UI for the current review status.
```

## How to brief Claude on resume

Paste something like:

> Vibecast V1 was submitted to App Store Connect on 2026-05-17 and is awaiting review. Read `docs/superpowers/notes/2026-05-18-launch-restart-context.md` for the snapshot. We're paused until Apple responds.

That gets you back in sync in one shot.
