# Development Prompt

Use this document later as the starting prompt for Codex when implementation begins.

## App Overview
Build a native iOS podcast app focused on a fixed-order subscriptions list. The main experience should let the user see every subscribed podcast as a single row in a vertically scrolling list, with each row staying in a stable, user-controlled position instead of moving based on episode recency.

Each row should expose the most recent episode for that podcast, whether that latest episode has already been listened to, and a quick way to start playback without drilling into a detail screen. The product goal is to improve on podcast apps that separate fixed subscription layout from recent-episode visibility.

## Build Goal
Build the MVP around one excellent home screen first, then add the minimum supporting screens needed for reordering and playback.

## Product Requirements
- Show all subscribed podcasts in one row-by-row list.
- Keep podcast order fixed according to a user-editable manual position.
- Show the latest episode for each podcast directly in its row.
- Show whether the latest episode has been listened to.
- Let the user start playing the latest episode directly from the row.
- Persist custom ordering and listened state locally.

## UX Requirements
- Use native iOS patterns.
- Keep the UI idiomatic to `SwiftUI`.
- Favor clear, testable view structure.
- Optimize the main screen for fast scanning and minimal taps.
- Prioritize information hierarchy so podcast identity, latest episode, and playback action are immediately understandable.

## Technical Requirements
- Build a native iOS app in `Swift` using `SwiftUI`.
- Prefer modern Apple frameworks.
- Keep the initial architecture simple and maintainable.
- Assume an iPhone-first MVP.
- Start with local persistence before adding cloud sync.

## Constraints
- Focus on the MVP only.
- Avoid speculative features not listed in the spec.
- Ask for clarification only when a decision materially affects implementation.

## References
- `specs/app-spec.md`
- `notes/ideas.md`
