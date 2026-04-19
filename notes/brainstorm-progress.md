# Brainstorm Progress — Vibecast Player Experience

## Decisions Locked In

### Mini-Player Bar
- Appears at the bottom of the screen when audio is playing
- Persists with the last-played podcast — not dismissable
- Layout (left to right):
  - Podcast artwork (44×44, rounded)
  - Episode title (truncated) above a thin progress bar
  - Progress bar with elapsed time on the left end, −remaining on the right end
  - Play/pause button
  - Skip-forward 30s button (circular arrow icon with "30" inside)

### Full-Screen Player
- **Opens:** tap anywhere on the mini-player bar → sheet slides up
- **Dismisses:** swipe down anywhere on the screen (native iOS sheet behavior)
- **Layout top to bottom:**
  - Drag handle pill at very top
  - "Now Playing" label
  - Large podcast artwork (with shadow)
  - Episode title + podcast name
  - Scrubber bar with elapsed left / −remaining right and draggable thumb
  - Playback controls: Jump back 15s — Play/pause (large white circle) — Jump forward 30s
  - Volume slider at the bottom (quiet speaker icon → track → loud speaker icon)
- **Out of scope for MVP:** playback speed control (future milestone)

---

## Still To Decide

1. **Adding podcasts** — where does the entry point live?
   - A: `+` button in the nav bar top-right
   - B: Dedicated Search tab in the tab bar
   - C: Floating `+` button (FAB) over the subscriptions list

2. **Removing a podcast** — how does a user unsubscribe?

3. **Reordering podcasts** — how does the user edit the fixed order of the main list?

4. **Importing subscriptions** — should MVP support importing from Apple Podcasts, Overcast, or OPML? (open question from original spec)
