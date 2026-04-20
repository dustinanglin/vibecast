# Vibecast MVP Design

## One-Sentence Pitch
A podcast app that shows every subscribed podcast in a fixed, user-controlled list so the latest episode and its listen status are visible and playable without drilling into submenus.

## Summary
Vibecast is for podcast listeners who want a stable, scan-friendly home screen instead of a recency-sorted feed or artwork grid. The core experience is a single row-by-row list of subscribed podcasts where each podcast keeps a fixed position chosen by the user and each row shows the most recent episode, whether it has been listened to, and a quick way to start playback.

The app improves on the default iOS Podcasts experience where a fixed grid hides current episode details, while the recent-episodes view loses positional stability because shows move around based on update cadence.

## Target User
Podcast listeners who subscribe to many shows and want to manage them from a predictable, low-friction overview.

## MVP Goal
Deliver a focused set of screens where a user can see all subscribed podcasts in a fixed order, review the latest episode for each, identify listen status, play episodes with minimal taps, browse a podcast's back catalog, and manage their subscription list.

---

## Screens

### 1. Subscriptions List (Home)
The primary screen. Vertically scrolling list of subscribed podcasts in fixed, user-controlled order. A persistent mini-player bar sits at the bottom whenever audio has been played.

**Navigation model:** No tab bar. Single home screen with sheet-based secondary screens.

### 2. Podcast Detail Sheet
Full episode history for a selected podcast. Opened by tapping the artwork or title area of any row on the subscriptions list. Dismissed by swiping down.

### 3. Add Podcast Sheet
Search and subscription management. Opened by tapping `+` in the nav bar. Dismissed by swiping down.

### 4. Full-Screen Player Sheet
Expanded playback controls. Opened by tapping the mini-player bar. Dismissed by swiping down.

---

## Subscriptions List

### Row Layout
Each podcast occupies exactly one row:
- **Left:** podcast artwork (44×44, rounded corners)
- **Right stack (top to bottom):**
  - Release time in relative format (`15m ago`, `4h ago`, `3d ago`) — small, de-emphasized — with inline explicit marker when applicable and completion checkmark when the latest episode is fully played
  - Episode title — largest text element, may wrap to two lines; uses stronger font weight for unlistened episodes, reduced weight for played or partially played episodes
  - Episode description — single line, truncated, smaller and lighter text; hidden when the title wraps to two lines
  - Play control with circular progress ring (fills to show completion) paired with time remaining (switches to full duration once episode is complete, and the play icon becomes a replay/refresh icon)

### Row Interactions
- **Tap artwork or title area** → opens Podcast Detail sheet
- **Tap play button** → begins playback of the latest episode; mini-player appears
- **Swipe right past halfway** → marks latest episode as played (commit animation, row returns to place)
- **Swipe right, release before halfway** → cancels, no state change
- **Long-press and drag** → lifts row for reordering; drop to new fixed position; persists across app launches
- **Swipe left** → reveals red Remove action to unsubscribe the podcast

### Rules
- Row order is user-defined, not sorted by latest publish date
- Each row shows only the latest episode
- If a podcast has no available episodes or feed refresh fails, show a clear fallback state
- An episode is considered listened only when fully played or explicitly marked as played

---

## Podcast Detail Sheet

### Header
Large podcast artwork, title, author name, short description.

### Episode List
- Sorted newest first
- Each episode row uses the same format as the subscriptions list row (play button with progress ring, listened-state typography, duration, description)
- Initial load: 10 episodes
- Infinite scroll: fetch the next 10 episodes as the user scrolls toward the bottom

### Navigation
- **Opened:** tap artwork or title area on any subscriptions list row
- **Dismissed:** swipe down

---

## Add Podcast Sheet

### Search
- Search field at top; results sorted by relevance
- Each result row: podcast artwork, title, brief description, circular `+` button on the right
- Tapping `+` subscribes immediately and adds the podcast to the bottom of the subscriptions list; button shifts to a muted checkmark to indicate already subscribed
- No separate detail view before subscribing — result row provides enough context

### OPML Import
- "Import from file" option in the sheet
- User exports subscriptions from Apple Podcasts (Settings → Export Subscriptions) and selects the OPML file via the system file picker
- All subscriptions are added in bulk; listen history and playback state are not imported and start fresh

---

## Mini-Player Bar

Persistent bar at the bottom of the subscriptions list whenever audio has been played. Not dismissable — always shows the last-played podcast.

**Layout (left to right):**
- Podcast artwork (44×44, rounded)
- Episode title (truncated) above a thin progress bar
- Progress bar with elapsed time label on the left end and −remaining time label on the right end
- Play/pause button
- Skip-forward 30s button (circular arrow icon with "30" inside)

**Behavior:**
- Tapping anywhere on the bar (except the play/pause and skip buttons) opens the Full-Screen Player sheet

---

## Full-Screen Player Sheet

**Opened:** tap anywhere on the mini-player bar
**Dismissed:** swipe down anywhere on the screen

**Layout (top to bottom):**
- Drag handle pill
- "Now Playing" label
- Large podcast artwork with drop shadow
- Episode title and podcast name
- Scrubber bar with draggable thumb; elapsed time on the left, −remaining on the right
- Playback controls: Jump back 15s — Play/pause (large filled circle) — Jump forward 30s
- Volume slider with quiet speaker icon on the left and loud speaker icon on the right

**Out of scope for MVP:** playback speed control (future milestone)

---

## Data Model

**Podcast**
- title, author, artwork URL, feed URL
- subscription status
- user-defined sort position
- latest episode ID, latest episode publish date

**Episode**
- podcast ID, title, publish date, description summary
- duration, audio URL
- playback state (current position, completed status, last played date)
- listened status

---

## Technical Preferences
- Platform: iOS (iPhone first)
- Language: Swift
- UI: SwiftUI
- Storage: local-first; CoreData or SwiftData for persistence
- Podcast search: iTunes Search API
- Sync: not in scope for MVP

---

## Out of Scope for MVP
- Playback speed control
- Social or collaborative features
- Podcast creation or publishing
- Advanced recommendation or discovery
- Cross-platform support
- Complex queue management or smart automation
- Showing multiple recent episodes per podcast on the main list
- Full downloaded-episodes management
- Importing playback state or listen history from other apps
- Cloud sync
- Sleep timer
- Notifications

---

## Future Milestones
- Playback speed control
- Downloaded episodes management for offline listening
- Richer queue and playlist features
- Import playback state from existing podcast apps
- Cloud sync
- Sleep timer
- Notifications

---

## Success Criteria
- A user can view all subscribed podcasts from one screen in a stable order they control
- A user can identify the latest episode and whether they have listened to it without opening each podcast
- A user can start playing the latest episode directly from the main list
- A user can rearrange podcasts and trust those positions to remain fixed over time
- A user can browse a podcast's episode history and play any episode with visible listen progress
- A user can add podcasts via search or bulk-import from Apple Podcasts
- A user can remove a podcast from their list with a swipe gesture
