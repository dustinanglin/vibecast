# App Spec

## App Name
[Working name]

## One-Sentence Pitch
A podcast app that shows every subscribed podcast in a fixed, user-controlled list so the latest episode and its listen status are visible and playable without drilling into submenus.

## Summary
This app is for podcast listeners who want a stable, scan-friendly home screen instead of a recency-sorted feed or artwork grid. The core experience is a single row-by-row list of subscribed podcasts, where each podcast keeps a fixed position chosen by the user and each row shows the most recent episode, whether it has been listened to, and a quick way to start playback.

The app is meant to improve on the default iOS Podcasts-style experience where a fixed grid of subscribed shows hides current episode details, while the recent-episodes view loses positional stability because shows move around based on update cadence.

## Target User
Podcast listeners who subscribe to many shows and want to manage them from a predictable, low-friction overview.

## User Problem
Existing podcast apps force a tradeoff between:

- a fixed subscriptions view that does not expose enough episode-level detail
- a recent-episodes view that exposes episode detail but constantly reorders shows based on release timing

This makes it harder for users to build a reliable habit around checking their shows, especially when some podcasts publish daily, some weekly, and some only a few times per month.

## MVP Goal
Deliver a single primary screen where a user can see all subscribed podcasts in a fixed order, review the latest episode for each one, identify whether that episode has already been listened to, and start playing that latest episode with minimal taps.

## Core Use Cases
- View all subscribed podcasts in one vertically scrolling list with stable, user-controlled ordering.
- Check the latest available episode for each subscribed podcast without opening the podcast detail page.
- See whether the latest episode has already been listened to.
- Start playing the latest episode for a podcast directly from the main list.
- Reorder podcasts so the list matches the user's personal priority or habit.

## Core Features
- A main subscriptions list showing one podcast per row.
- Fixed manual ordering of podcasts, editable by the user.
- Per-row display of latest episode title and relevant episode metadata.
- Per-row listened or unlistened state for the latest episode.
- Quick play action from the row for the latest episode.
- Built-in playback support for listening inside the app.

## Out Of Scope For MVP
- Social or collaborative podcast features.
- Podcast creation or publishing tools.
- Advanced recommendation systems.
- Cross-platform support outside iOS.
- Complex playlisting, queue management, or smart automation unless needed for the core row-based workflow.
- Showing multiple recent episodes per podcast in the main list.
- Full downloaded-episodes management beyond what is needed for the single latest-episode workflow.

## Main Screens
- Home / Subscriptions List: The primary screen showing all subscribed podcasts in a fixed row order with latest episode details.
- Reorder / Edit Mode: A mode or screen where the user can change the fixed order of podcasts.
- Podcast Detail: Optional secondary screen to view older episodes and more show-specific information.
- Player / Now Playing: Playback controls for the selected episode.

## Primary User Flow
The user opens the app and lands on the subscriptions list. They scan the rows in their familiar fixed order, notice which podcasts have a new or unplayed latest episode, and tap play on the one they want to hear. If they want to change priorities, they enter edit or reorder mode and move podcasts to new fixed positions. Over time, the list remains stable while the latest episode information updates within each row.

## Data Model
- Podcast: title, author, artwork URL, feed URL, subscription status, user-defined sort position, latest episode ID, latest episode publish date
- Episode: podcast ID, title, publish date, description summary, duration, audio URL, playback state, listened status
- Playback State: current position, completed status, last played date

## Rules And Behavior
- Each subscribed podcast occupies exactly one row in the main list.
- The row order is determined by a user-editable fixed position, not by latest publish date.
- The latest episode shown for a podcast is the most recent available episode from that podcast's feed.
- For MVP, the main list should only show the latest episode for each podcast.
- A listened indicator should clearly distinguish between fully listened and not yet listened states for the latest episode.
- The main list should prioritize fast scanning and low tap count over dense secondary metadata.
- Reordering a podcast should persist across app launches.
- If a podcast has no available episodes or its feed cannot be refreshed, the UI should show a clear fallback state.
- For MVP, an episode is considered listened only when it has been fully played or explicitly marked as played by the user.

## Podcast Row Layout
- Each podcast appears as a single row in the main list.
- The left side of the row shows the podcast artwork.
- The right side of the row shows metadata for the latest episode in a vertical information stack.

## Podcast Row Fields
- Podcast artwork on the left.
- Release time for the latest episode in relative format such as `15m ago`, `4h ago`, or `3d ago`.
- Explicit marker next to the release time when the episode or podcast is marked explicit.
- Completion checkmark next to the release time when the latest episode has been fully played or manually marked as played.
- Latest episode title as the primary text element. This is the largest text in the row and may wrap to a second line if needed.
- Episode description as a secondary text element. This should appear in smaller, lighter text and be limited to a single line with truncation.
- Play control paired with the episode duration in a format such as `1h 15m`.

## Podcast Row Behavior Rules
- The release time should be visually small and de-emphasized compared with the title.
- The explicit marker should appear inline with the release time and should only appear when applicable.
- The episode title should remain the dominant content element in the row.
- The episode description should disappear when the title wraps to two lines or otherwise needs the vertical space.
- The play control and duration should remain quickly tappable from the main list without requiring navigation to another screen.
- The row should make it easy to determine at a glance whether there is a new episode worth attention.
- The listened or unlistened state should be communicated primarily through typography, similar to email apps where unread items use stronger text emphasis.
- Unlistened episodes should use stronger font weight for the episode title.
- Played or partially played episodes should use a reduced emphasis style for the episode title.
- The play control should include a compact playback progress indicator that fills to show how much of the episode has been completed.
- The duration label associated with the play control should show time remaining rather than full episode length once playback has started.
- Once an episode is fully completed, the play control should switch to a replay action using a refresh-style icon and the duration label should return to the full original episode length.

## Swipe Interaction
- Swiping a row to the right should reveal a `Played` action from the left side of the row, similar to common email-style gesture patterns.
- If the swipe passes a defined commitment threshold, approximately halfway across the row, the action should lock in and trigger a completion animation such as a checkmark confirmation.
- When the user releases after crossing the threshold, the row should animate back into place and the episode should be marked as played.
- If the user releases before crossing the threshold, the row should return to its default state without changing playback status.
- The swipe interaction should feel fast, deliberate, and satisfying, with clear visual confirmation when the episode has been marked played.

## Notifications
Undecided. Notifications are not required for the MVP unless they support the main fixed-list workflow in a simple way.

## Authentication
None for the initial MVP unless external sync or account-backed subscriptions become necessary.

## Storage And Sync
Likely local-first for MVP. Subscription state, row order, and listened state should persist on device. Cloud sync is a later decision.

## Design Direction
The app should feel utility-first, fast to scan, and optimized for habit. The most important design goal is that the main list is more informative than a podcast artwork grid while still feeling lightweight and easy to parse. The visual hierarchy should emphasize podcast identity first, latest episode second, and actionability third. Native iOS interaction patterns should be preserved, but the UX should avoid hiding key information behind extra taps.

The listened-state treatment should feel subtle and familiar rather than noisy. A typography-based distinction between unplayed and already-started items is preferred over large badges or heavy status labels. Playback progress should be visible in a compact way near the play control so users can instantly tell whether an episode is untouched, in progress, or nearly complete.

The swipe-to-mark-played interaction should borrow from the best parts of email apps: gesture-based, confidence-inspiring, and visually rewarding. The completion state should be visible both in the row title treatment and in a compact completion marker near the top metadata line.

## Technical Preferences
- Platform: iOS
- UI: SwiftUI
- Language: Swift
- Device Support: iPhone first
- Minimum OS: Undecided

## Future Milestones
- A dedicated podcast detail page that shows the full episode list for a selected show.
- Downloaded episodes management for keeping multiple episodes available offline.
- Richer playback and queue features once the main fixed-list workflow is solid.
- Import tools for subscriptions and playback state from existing podcast apps.
- Optional sync features if local-only storage becomes limiting.

## Next Requirements To Lock Down
- Define the MVP built-in player experience, including which playback controls are required on day one.
- Define how users search for and add podcasts to the app.
- Define how users remove a podcast from the app.
- Define how users edit the order of podcasts in the main view.

## Success Criteria
- A user can view all subscribed podcasts from one screen in a stable order they control.
- A user can identify the latest episode and whether they have listened to it without opening each podcast.
- A user can start playing the latest episode directly from the main list.
- A user can rearrange podcasts and trust those positions to remain fixed over time.

## Open Questions
- Should the app support importing subscriptions and playback state from Apple Podcasts, Overcast, or another source?
- What is the minimum built-in player experience for MVP?
