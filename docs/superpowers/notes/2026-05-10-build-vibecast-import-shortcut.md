# Building the "Vibecast Import" Shortcut

A walkthrough for building the iOS Shortcuts shortcut that bridges Apple Podcasts subscriptions into Vibecast. This is **Task 1** of the Apple Podcasts import plan — one-time manual setup on your iPhone.

## Overview

The shortcut runs entirely inside the iOS Shortcuts app. It reads your Apple Podcasts library, extracts each podcast's RSS Feed URL, joins them with newlines, URL-encodes the result, and opens `vibecast://import-feeds?urls=<encoded>` — which Vibecast receives and turns into bulk subscribes.

## Setup

1. Open the **Shortcuts** app on your iPhone (iOS 17+).
2. Tap the **`+`** (top right) to start a new shortcut.
3. Add the actions in the order below.

## Action 1: Get Podcasts from Library

- Tap **"Add Action"**
- Search "Get Podcasts from Library" → tap it
- This produces a list of all your subscribed Apple Podcasts shows.

## Action 2: Repeat with Each

- `+` → search "Repeat with Each" → tap it
- The action's input auto-fills with **"Podcasts"** (the output of the previous action). Good — leave it.
- You'll see a `Repeat with Each` / `End Repeat` block. The next several actions go **inside** this loop.

## Action 3: Get Details of Podcast (inside the loop)

- Tap the `+` between `Repeat with Each` and `End Repeat`
- Search "Get Details of Podcast" → tap it
- Input: tap the placeholder → pick **"Repeat Item"** (the magic variable that represents the current podcast in the loop)
- Tap the **property** dropdown (says "Title" by default) → choose **"Feed URL"**

This produces a magic variable named something like "Details of Podcasts" — that's the Feed URL string for the current podcast.

## Action 4: If — has any value (still inside the loop)

Some Apple Podcasts subscriptions (Apple Originals, channels) have no public RSS feed. We skip those.

- `+` → search "If" → tap it
- For the input, tap the placeholder → pick the magic variable from Action 3 (it'll be labeled **"Details of Podcasts"** or similar — it's the Feed URL)
- Tap the condition dropdown → choose **"has any value"**

You'll see an `If` / `Otherwise` / `End If` block inside the loop.

## Action 5: Add to Variable (inside the If block)

This is the accumulator — each iteration where the Feed URL exists appends it to a list called "Feeds."

- Tap the `+` between `If` and `Otherwise`
- Search "Add to Variable" → tap it
- For the input, tap the placeholder → pick the same **Details/Feed URL** magic variable from Action 3
- In the **"Variable Name"** field, type exactly: **`Feeds`**

You can leave the `Otherwise` branch empty (or long-press → Delete it — both work).

> **Why no Text action here?** When you `Add to Variable` repeatedly, Shortcuts builds a list-typed variable automatically. The next step joins it with newlines — no manual concatenation needed.

## Action 6: End Repeat

This is already there from when you added `Repeat with Each`. The next actions go **below** this — *outside* the loop.

## Action 7: Combine Text (below the loop)

- `+` (below `End Repeat`) → search "Combine Text" → tap it
- For the input, tap the placeholder → pick the **`Feeds`** variable (it'll appear in the variable picker)
- For **"Separator,"** tap the dropdown → choose **"New Lines"**

This joins all the feed URLs into one text blob with each URL on its own line.

## Action 8: URL Encode

- `+` → search "URL Encode" → tap it
- The input auto-fills with **"Combined Text"** from Action 7. Leave it.

## Action 9: Text — build the final URL

- `+` → search "Text" → tap it
- In the text field, type literally:
  ```
  vibecast://import-feeds?urls=
  ```
- Without leaving the text field, tap the **variable-picker icon** above the keyboard (looks like a small chip/pill) → pick **"URL Encoded Text"** from the list

The Text action should now look like:

```
vibecast://import-feeds?urls=[URL Encoded Text]
```

(where `[URL Encoded Text]` is a pill-shaped variable token, not literal text)

## Action 10: Open URLs

- `+` → search "Open URLs" → tap it
- The input auto-fills with the text from Action 9. Leave it.

## Name the shortcut

- Tap the shortcut's title at the top of the screen
- Rename to exactly **`Vibecast Import`** (capital V, capital I, single space)

The exact name matters — the app's "Run Shortcut" button deep-links to `shortcuts://run-shortcut?name=Vibecast%20Import`.

## Test the shortcut

Before publishing, sanity-check that it produces a well-formed URL.

1. **Temporarily replace Action 10 (Open URLs) with "Show Result":**
   - Long-press the `Open URLs` row → Delete
   - `+` → search "Show Result" → tap it
   - Input auto-fills with the Text from Action 9

2. Tap the shortcut's **play button** (▶︎) at the top to run it.

3. A dialog appears showing the constructed URL. It should look like:
   ```
   vibecast://import-feeds?urls=https%3A%2F%2Ffeeds.simplecast.com%2F...%0Ahttps%3A%2F%2Ffeeds.npr.org%2F...
   ```
   - Starts with `vibecast://import-feeds?urls=`
   - Contains URL-encoded feed URLs
   - URLs separated by `%0A` (URL-encoded newline)

4. If it looks right, **swap "Show Result" back to "Open URLs"** — long-press → Delete, then re-add `Open URLs` with the Text variable as input.

## Share to iCloud and capture the URL

1. Back at the Shortcuts home screen, **long-press** the "Vibecast Import" tile
2. Tap **"Share"** → **"iCloud Link"**
3. Shortcuts uploads it and the share sheet shows a URL like:
   ```
   https://www.icloud.com/shortcuts/abc123def456…
   ```
4. **Copy that URL** — paste it back into the chat so Claude can bake it into Task 8.

## Smoke test the install link (optional but recommended)

Before declaring Task 1 done:

1. Open the iCloud URL in Safari on a *second* device (or after deleting the shortcut from your library)
2. The page should show a "Get Shortcut" dialog with the shortcut preview
3. Tap "Add Shortcut" — the shortcut should appear in your library with the name "Vibecast Import"

If the install dialog doesn't show or the name is wrong, fix the shortcut and re-share to iCloud.

## What's next

Paste the iCloud share URL back into the chat. Claude will:
- Start dispatching subagents for Tasks 2–7 (the in-app code work)
- Bake your iCloud URL into Task 8's `AddPodcastSheet` integration
- Hand back to you for Task 10 (end-to-end manual verification on device)

## Troubleshooting

**"Get Podcasts from Library" doesn't appear in the action search.**
You may need to scroll to the Podcasts app's section, or your iOS version may not include this action. The action was added in iOS 17 and exists through current iOS releases.

**The "Feed URL" property dropdown shows different options.**
Different iOS versions sometimes name properties slightly differently — try "RSS Feed," "Feed," or "URL" if "Feed URL" isn't present. Pick whichever yields a public `https://...feed.xml`-style URL when run.

**The Show Result test shows an empty `?urls=` parameter.**
The Apple Podcasts library is empty, or all your shows are Apple Originals (no RSS). Subscribe to a regular podcast in Apple Podcasts first, then re-run.

**The Combined Text shows `,` separators instead of newlines.**
"Combine Text" defaults to "," — double-check the Separator dropdown is set to **"New Lines"** (not "Custom" with an empty separator).
