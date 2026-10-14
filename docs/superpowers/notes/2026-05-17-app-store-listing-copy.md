# Vibecast 1.0 — App Store Connect Submission Copy

Everything to fill in App Store Connect → My Apps → Vibecast → 1.0 Prepare for Submission, in one place.

---

## App Information

### App name (30 char)

```
Vibecast
```

### Subtitle (30 char)

```
Listen with intent.
```

### Primary language

```
English (U.S.)
```

### Bundle ID

```
AnglinVibes.Vibecast
```

### Category

- **Primary:** Music
- **Secondary:** News

### Content Rights

- Check the box: "Does not contain, show, or access third-party content." (Vibecast hosts no content of its own — it plays publicly-available RSS feeds the user chose.)

---

## Pricing & Availability

- **Price:** Free
- **Availability:** All countries / regions

---

## App Privacy

Single question that collapses the entire questionnaire:

> Do you or your third-party partners collect data from this app?

**→ No**

Vibecast has zero data collection. SwiftData lives in the app sandbox. The only network traffic is direct to publishers and Apple's iTunes Search.

---

## 1.0 — Version Information

### Promotional text (170 char, editable post-submission without re-review)

```
Vibecast organizes your podcasts into small moods — morning, around the house, a workout — and plays the show that fits the moment, in order, in one tap.
```

### Description (4000 char limit, currently ~1500)

```
Vibecast is an editorial podcast player for iPhone, built around a small idea: the right podcast depends on the mood you're in.

Subscribe to your shows. Group them into vibes — small playlists for the moments you actually listen. Morning. Around the house. A workout. Wind down. Deep work. Then one tap starts the vibe, and Vibecast plays through the unplayed episodes of every show in that vibe, in your order.

That's the whole app. No feed. No social. No autoplay across vibes you didn't ask for. No tracking.

— Five seeded vibes ship with the app. Rename them, recolor them, reorder them, or build new ones from the same palette.
— Each show keeps its own sort order. Newest first for daily news; oldest first for serialized shows like sermons or multi-part series.
— Import your existing podcast library in a few taps via a one-time Shortcuts shortcut. Nothing leaves your phone.
— Search the iTunes catalog to find new shows. Subscribe with one tap.
— Background audio, lock screen controls, AirPlay — everything you expect from a real podcast app.

Privacy is structural, not promotional. Vibecast has no backend. Subscriptions, playback positions, and listening history live entirely on your device. No accounts. No analytics. No ads. No third-party SDKs.

Listen with intent.
```

### Keywords (100 char, comma-separated, NOT visible to users)

```
podcast,podcasts,player,audio,subscribe,RSS,playlist,mood,vibe,queue,shows,listen,episodes
```

### Support URL

```
https://vibecastplayer.app/support.html
```

### Marketing URL (optional)

```
https://vibecastplayer.app/
```

### Privacy Policy URL

```
https://vibecastplayer.app/privacy.html
```

### Copyright

```
© 2026 Dustin Anglin
```

### What's New in This Version (4000 char, for v1)

```
First version. Welcome to Vibecast.
```

---

## App Review Information

### Sign-in required

**→ No** (no account)

### Contact Information

- **First name:** Dustin
- **Last name:** Anglin
- **Phone number:** [your phone]
- **Email:** support@vibecastplayer.app

### Notes

```
Hello,

Vibecast is a standalone podcast player. No account is required.

To test the basic subscribe flow:
1. Open the app — first launch plays a brief animated splash.
2. Tap "+" in the top right.
3. Search for any podcast (e.g. "Hard Fork", "The Daily").
4. Tap subscribe. Episodes populate within a few seconds.

To test the optional "Import Podcasts from this Phone" feature:
1. The button sits above "Import from File" in the "+" sheet.
2. The wizard installs a Shortcuts shortcut that reads on-device podcast library data and passes RSS feed URLs to Vibecast via a custom URL scheme. No subscription data leaves the device.
3. Hosted shortcut: https://www.icloud.com/shortcuts/edfe11df98fc418094340da723418f6e

Privacy: Vibecast has no backend. Listening history, subscriptions, and playback state live locally via SwiftData. Network traffic is direct device-to-publisher (RSS, audio) and to Apple's iTunes Search API for in-app search.

Privacy policy: https://vibecastplayer.app/privacy.html
Support: https://vibecastplayer.app/support.html

Thank you.
```

### Attachments

None needed. The hosted shortcut URL in the notes is sufficient for the reviewer to test the import flow.

---

## Age Rating

Click through the questionnaire — answer **None** for every category. Specific items to double-check:

- **Unrestricted Web Access** → **No**
  Vibecast doesn't expose an arbitrary web browser. RSS / audio fetches are not "web access" in App Review's terminology.
- **User Generated Content** → **No**
  Users create vibes (just labels + colors) but nothing is shared externally.
- **Gambling, Contests** → **No**
- **Medical / Health / Treatment** → **No**

Final rating: **4+**.

---

## Build

Pick the latest TestFlight build that includes the v1 prep changes (commit `eb73da4` or later — has the rename to "Import Podcasts from this Phone", debug-swipe removal, sort feature, and the dedup + empty-CTA polish).

---

## Export Compliance

Vibecast already has `ITSAppUsesNonExemptEncryption = false` set in Info.plist, so Apple should auto-handle this and not prompt during submission.

If Apple does prompt:

- **Does your app use encryption?** → Yes (HTTPS counts)
- **Does your app qualify for any of the exemptions?** → Yes
- **Specifically:** "Your app uses, accesses, contains, implements, or incorporates encryption only in the following ways:" → check the box for **"making calls over secure channels (e.g. HTTPS, SSL, VPN)"** — that's the standard exemption for HTTPS-only apps.

---

## Submission Order

1. Fill all App Information fields (name, subtitle, category, rights).
2. Fill 1.0 Version Information (promo text, description, keywords, URLs, copyright, what's new).
3. Fill App Privacy (single No question).
4. Upload screenshots.
5. Pick the build.
6. Fill App Review Information (notes + contact).
7. Set age rating.
8. **Wait for HTTPS cert to provision on vibecastplayer.app** before hitting Submit (the reviewer might click the privacy URL and seeing only HTTP could trigger a metadata rejection).
9. Hit Submit for Review.

Reviews currently average 24-48 hours.
