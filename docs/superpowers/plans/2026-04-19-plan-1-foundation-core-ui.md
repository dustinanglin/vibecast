# Vibecast MVP — Plan 1: Foundation & Core UI

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a working iOS app with SwiftData persistence showing the complete subscriptions list UI — all podcast row states, gesture interactions (swipe to mark played, swipe to remove, long-press to reorder), and podcast detail sheet — running on sample data with audio playback stubbed out.

**Architecture:** SwiftData `@Model` entities for Podcast and Episode. `@Observable` ViewModels mediate between the SwiftData `ModelContext` and SwiftUI views. All screens are SwiftUI sheets — no tab bar, no pushed navigation for MVP. Audio playback is a no-op stub in this plan; the full UI is testable independently of real audio.

**Tech Stack:** Swift 5.9+, SwiftUI, SwiftData, XCTest, iOS 17+

---

## Scope

This is **Plan 1 of 3**.

- **Plan 2** — Audio engine: AVFoundation integration, mini-player bar, full-screen player sheet, real playback state tracking.
- **Plan 3** — Podcast discovery: iTunes Search API, RSS feed parsing, OPML import, add-podcast sheet.

After this plan the app runs with sample data, all gestures work, and the detail sheet paginates correctly.

---

## File Map

```
Vibecast/
├── VibecastApp.swift                    — entry point, ModelContainer setup
├── Models/
│   ├── Podcast.swift                     — @Model: title, author, artworkURL, feedURL, sortPosition
│   └── Episode.swift                     — @Model: title, date, description, duration, audioURL,
│                                           listenedStatus, playbackPosition; computed helpers
├── ViewModels/
│   ├── SubscriptionsViewModel.swift      — fetch, reorder, remove, mark-played
│   └── PodcastDetailViewModel.swift      — paginated episode list for one podcast
├── Views/
│   ├── SubscriptionsListView.swift       — NavigationStack, List of PodcastRowView
│   ├── PodcastRowView.swift              — artwork + metadata + play control; split tap targets
│   ├── PlayControlView.swift             — circular progress ring, play/replay icon, duration label
│   ├── EpisodeRowView.swift              — metadata + play control; used in detail sheet
│   └── PodcastDetailView.swift           — sheet: header + paginated EpisodeRowView list
└── Preview Content/
    └── SampleData.swift                  — in-memory ModelContainer, 5 podcasts × 12 episodes each

VibecastTests/
├── ModelTests.swift                      — Podcast and Episode model behaviour
└── SubscriptionsViewModelTests.swift     — reorder, remove, mark-played logic
```

---

## Task 1: Create Xcode Project

**Files:**
- Create: `Vibecast.xcodeproj` (via Xcode GUI)

- [ ] **Step 1: Create the project**

  Open Xcode → File → New → Project → iOS → App.

  | Field | Value |
  |---|---|
  | Product Name | `Vibecast` |
  | Interface | SwiftUI |
  | Storage | SwiftData |
  | Language | Swift |
  | Minimum Deployments | iOS 17.0 |

- [ ] **Step 2: Delete generated placeholder files**

  In Xcode's file navigator delete `ContentView.swift` and `Item.swift` (the generated SwiftData example model). Keep `VibecastApp.swift` and `Assets.xcassets`.

- [ ] **Step 3: Create folder groups**

  Right-click the `Vibecast` group in the navigator → New Group (without folder). Create: `Models`, `ViewModels`, `Views`, `Preview Content`.

- [ ] **Step 4: Confirm the test target exists**

  Xcode creates `VibecastTests/` automatically. Delete the placeholder `VibecastTests.swift` inside it.

- [ ] **Step 5: Temporarily fix the entry point so the app builds**

  ```swift
  // Vibecast/VibecastApp.swift
  import SwiftUI

  @main
  struct VibecastApp: App {
      var body: some Scene {
          WindowGroup {
              Text("Vibecast")
          }
      }
  }
  ```

- [ ] **Step 6: Build and run**

  Cmd+R. Expected: simulator shows "Vibecast" text, no crash.

- [ ] **Step 7: Commit**

  ```bash
  git add .
  git commit -m "feat: create Xcode project scaffold"
  ```

---

## Task 2: Data Models

**Files:**
- Create: `Vibecast/Models/Podcast.swift`
- Create: `Vibecast/Models/Episode.swift`
- Create: `VibecastTests/ModelTests.swift`

- [ ] **Step 1: Write failing model tests**

  Create `VibecastTests/ModelTests.swift`:

  ```swift
  import XCTest
  import SwiftData
  @testable import Vibecast

  @MainActor
  final class ModelTests: XCTestCase {
      var container: ModelContainer!
      var context: ModelContext!

      override func setUp() async throws {
          let config = ModelConfiguration(isStoredInMemoryOnly: true)
          container = try ModelContainer(
              for: Podcast.self, Episode.self,
              configurations: config
          )
          context = ModelContext(container)
      }

      func test_podcast_defaultSortPosition_isZero() throws {
          let p = Podcast(title: "Test", author: "Author", artworkURL: nil, feedURL: "https://example.com/feed")
          context.insert(p)
          try context.save()
          XCTAssertEqual(p.sortPosition, 0)
      }

      func test_episode_defaultListenedStatus_isUnplayed() throws {
          let p = Podcast(title: "Test", author: "Author", artworkURL: nil, feedURL: "https://example.com/feed")
          let e = Episode(podcast: p, title: "Ep 1", publishDate: .now, descriptionText: "Desc", durationSeconds: 3600, audioURL: "")
          context.insert(p)
          context.insert(e)
          try context.save()
          XCTAssertEqual(e.listenedStatus, .unplayed)
          XCTAssertEqual(e.playbackPosition, 0)
      }

      func test_episode_progressFraction_isZeroWhenUnplayed() throws {
          let p = Podcast(title: "Test", author: "Author", artworkURL: nil, feedURL: "https://example.com/feed")
          let e = Episode(podcast: p, title: "Ep 1", publishDate: .now, descriptionText: "", durationSeconds: 3600, audioURL: "")
          XCTAssertEqual(e.progressFraction, 0.0)
      }

      func test_episode_progressFraction_isCorrectWhenInProgress() throws {
          let p = Podcast(title: "Test", author: "Author", artworkURL: nil, feedURL: "https://example.com/feed")
          let e = Episode(podcast: p, title: "Ep 1", publishDate: .now, descriptionText: "", durationSeconds: 3600, audioURL: "")
          e.playbackPosition = 1800
          XCTAssertEqual(e.progressFraction, 0.5, accuracy: 0.001)
      }

      func test_episode_remainingSeconds_decreasesWithPlayback() throws {
          let p = Podcast(title: "Test", author: "Author", artworkURL: nil, feedURL: "https://example.com/feed")
          let e = Episode(podcast: p, title: "Ep 1", publishDate: .now, descriptionText: "", durationSeconds: 3600, audioURL: "")
          e.playbackPosition = 600
          XCTAssertEqual(e.remainingSeconds, 3000)
      }
  }
  ```

- [ ] **Step 2: Run tests — verify they fail with compiler errors**

  Cmd+U. Expected: compiler errors — `Podcast`, `Episode`, `ListenedStatus` not defined.

- [ ] **Step 3: Create `Podcast.swift`**

  ```swift
  // Vibecast/Models/Podcast.swift
  import SwiftData
  import Foundation

  @Model
  final class Podcast {
      var title: String
      var author: String
      var artworkURL: String?
      var feedURL: String
      var sortPosition: Int
      @Relationship(deleteRule: .cascade) var episodes: [Episode]

      init(title: String, author: String, artworkURL: String?, feedURL: String, sortPosition: Int = 0) {
          self.title = title
          self.author = author
          self.artworkURL = artworkURL
          self.feedURL = feedURL
          self.sortPosition = sortPosition
          self.episodes = []
      }
  }
  ```

- [ ] **Step 4: Create `Episode.swift`**

  ```swift
  // Vibecast/Models/Episode.swift
  import SwiftData
  import Foundation

  enum ListenedStatus: String, Codable {
      case unplayed
      case inProgress
      case played
  }

  @Model
  final class Episode {
      var podcast: Podcast?
      var title: String
      var publishDate: Date
      var descriptionText: String
      var durationSeconds: Int
      var audioURL: String
      var listenedStatus: ListenedStatus
      var playbackPosition: Double  // seconds elapsed

      init(podcast: Podcast, title: String, publishDate: Date, descriptionText: String, durationSeconds: Int, audioURL: String, isExplicit: Bool = false) {
          self.podcast = podcast
          self.title = title
          self.publishDate = publishDate
          self.descriptionText = descriptionText
          self.durationSeconds = durationSeconds
          self.audioURL = audioURL
          self.isExplicit = isExplicit
          self.listenedStatus = .unplayed
          self.playbackPosition = 0
      }

      var isExplicit: Bool

      var progressFraction: Double {
          guard durationSeconds > 0 else { return 0 }
          return min(playbackPosition / Double(durationSeconds), 1.0)
      }

      var remainingSeconds: Int {
          max(0, durationSeconds - Int(playbackPosition))
      }

      var formattedDuration: String {
          Self.format(seconds: durationSeconds)
      }

      var formattedRemaining: String {
          Self.format(seconds: remainingSeconds)
      }

      private static func format(seconds total: Int) -> String {
          let h = total / 3600
          let m = (total % 3600) / 60
          if h > 0 { return "\(h)h \(m)m" }
          return "\(m)m"
      }
  }
  ```

- [ ] **Step 5: Run tests — verify all 5 pass**

  Cmd+U. Expected: 5 tests pass, 0 failures.

- [ ] **Step 6: Commit**

  ```bash
  git add Vibecast/Models/Podcast.swift Vibecast/Models/Episode.swift VibecastTests/ModelTests.swift
  git commit -m "feat: add Podcast and Episode SwiftData models"
  ```

---

## Task 3: ModelContainer Setup + Sample Data

**Files:**
- Modify: `Vibecast/VibecastApp.swift`
- Create: `Vibecast/Preview Content/SampleData.swift`

- [ ] **Step 1: Update `VibecastApp.swift`**

  ```swift
  // Vibecast/VibecastApp.swift
  import SwiftUI
  import SwiftData

  @main
  struct VibecastApp: App {
      var body: some Scene {
          WindowGroup {
              Text("Vibecast")
          }
          .modelContainer(for: [Podcast.self, Episode.self])
      }
  }
  ```

- [ ] **Step 2: Create `SampleData.swift`**

  Five podcasts, twelve episodes each, varied listen states so every UI state is previewable.

  ```swift
  // Vibecast/Preview Content/SampleData.swift
  import SwiftData
  import Foundation

  @MainActor
  struct SampleData {
      static let container: ModelContainer = {
          let config = ModelConfiguration(isStoredInMemoryOnly: true)
          let c = try! ModelContainer(for: Podcast.self, Episode.self, configurations: config)
          insertSampleData(into: ModelContext(c))
          return c
      }()

      static func insertSampleData(into context: ModelContext) {
          let specs: [(String, String)] = [
              ("Hard Fork", "The New York Times"),
              ("Acquired", "Ben Gilbert and David Rosenthal"),
              ("The Vergecast", "The Verge"),
              ("Darknet Diaries", "Jack Rhysider"),
              ("Planet Money", "NPR"),
          ]

          for (position, (podcastTitle, author)) in specs.enumerated() {
              let podcast = Podcast(
                  title: podcastTitle,
                  author: author,
                  artworkURL: nil,
                  feedURL: "https://feeds.example.com/\(podcastTitle.lowercased().replacingOccurrences(of: " ", with: "-"))",
                  sortPosition: position
              )
              context.insert(podcast)

              // 12 episodes per podcast, newest first
              for i in 0..<12 {
                  let daysAgo = Double(i) * 7
                  let duration = [3600, 4500, 2700, 5400, 3900, 6600][i % 6]
                  let ep = Episode(
                      podcast: podcast,
                      title: sampleTitle(podcast: podcastTitle, index: i),
                      publishDate: Date().addingTimeInterval(-daysAgo * 86400),
                      descriptionText: sampleDescription(index: i),
                      durationSeconds: duration,
                      audioURL: ""
                  )
                  // Vary listen state across episodes
                  switch i {
                  case 0 where position == 1:
                      // Podcast 1 latest episode is in-progress
                      ep.listenedStatus = .inProgress
                      ep.playbackPosition = Double(duration) * 0.35
                  case 0 where position == 2:
                      // Podcast 2 latest episode is fully played
                      ep.listenedStatus = .played
                      ep.playbackPosition = Double(duration)
                  case 1, 2, 3:
                      ep.listenedStatus = .played
                      ep.playbackPosition = Double(duration)
                  default:
                      break
                  }
                  context.insert(ep)
                  podcast.episodes.append(ep)
              }
          }

          try? context.save()
      }

      private static func sampleTitle(podcast: String, index: Int) -> String {
          let titles = [
              "The Future of AI Regulation in Europe",
              "How Figma Became the Design Standard",
              "Inside the Semiconductor Supply Chain",
              "The Long Road to Autonomous Vehicles and What It Means for Cities",
              "Why the Dollar Is Still King",
              "The Social Media Paradox",
              "Rethinking the Office",
              "Climate Tech's Quiet Revolution",
              "The Streaming Wars Are Not Over",
              "What Happened to Crypto",
              "The Rise of the Creator Economy",
              "Big Tech Under Pressure",
          ]
          return titles[index % titles.count]
      }

      private static func sampleDescription(index: Int) -> String {
          let descs = [
              "New rules could reshape how companies deploy large language models across the EU.",
              "A deep dive into collaborative design tools and why they won.",
              "From Taiwan to Texas: the geopolitics of chip manufacturing.",
              "Self-driving cars keep failing. Here is why the timeline keeps slipping.",
              "The global reserve currency and its uncertain future in a multipolar world.",
              "Platforms that promised connection are delivering anxiety instead.",
          ]
          return descs[index % descs.count]
      }
  }
  ```

- [ ] **Step 3: Build — verify no errors**

  Cmd+B. Expected: builds successfully.

- [ ] **Step 4: Commit**

  ```bash
  git add Vibecast/VibecastApp.swift "Vibecast/Preview Content/SampleData.swift"
  git commit -m "feat: configure ModelContainer and add sample preview data"
  ```

---

## Task 4: PlayControlView

**Files:**
- Create: `Vibecast/Views/PlayControlView.swift`

Renders the circular progress ring, play/replay icon inside it, and a duration label below. Accepts an episode and a tap closure so it works in any context without needing a ViewModel.

- [ ] **Step 1: Create `PlayControlView.swift`**

  ```swift
  // Vibecast/Views/PlayControlView.swift
  import SwiftUI

  struct PlayControlView: View {
      let episode: Episode
      let onTap: () -> Void

      private var ringColor: Color {
          switch episode.listenedStatus {
          case .unplayed:  return .clear
          case .inProgress: return .accentColor
          case .played:    return .accentColor.opacity(0.35)
          }
      }

      private var iconName: String {
          episode.listenedStatus == .played ? "arrow.clockwise" : "play.fill"
      }

      private var durationLabel: String {
          switch episode.listenedStatus {
          case .unplayed:   return episode.formattedDuration
          case .inProgress: return episode.formattedRemaining
          case .played:     return episode.formattedDuration
          }
      }

      var body: some View {
          VStack(spacing: 4) {
              Button(action: onTap) {
                  ZStack {
                      // Track
                      Circle()
                          .stroke(Color.secondary.opacity(0.2), lineWidth: 2.5)
                          .frame(width: 36, height: 36)

                      // Progress
                      if episode.progressFraction > 0 {
                          Circle()
                              .trim(from: 0, to: episode.progressFraction)
                              .stroke(ringColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                              .frame(width: 36, height: 36)
                              .rotationEffect(.degrees(-90))
                      }

                      // Icon
                      Image(systemName: iconName)
                          .font(.system(size: 12, weight: .semibold))
                          .foregroundStyle(.primary)
                  }
              }
              .buttonStyle(.plain)

              Text(durationLabel)
                  .font(.system(size: 10))
                  .foregroundStyle(.secondary)
          }
      }
  }

  #Preview {
      let container = SampleData.container
      let episodes = try! ModelContext(container).fetch(FetchDescriptor<Episode>())
      return HStack(spacing: 24) {
          // Unplayed
          PlayControlView(episode: episodes[0], onTap: {})
          // In-progress
          PlayControlView(episode: episodes[12], onTap: {})
          // Played
          PlayControlView(episode: episodes[24], onTap: {})
      }
      .modelContainer(container)
      .padding()
  }
  ```

- [ ] **Step 2: Open Xcode canvas and verify all three ring states render correctly**

  Expected: empty ring (unplayed), partial accent ring (in-progress), faded full ring with clockwise arrow (played).

- [ ] **Step 3: Commit**

  ```bash
  git add Vibecast/Views/PlayControlView.swift
  git commit -m "feat: add PlayControlView with circular progress ring"
  ```

---

## Task 5: EpisodeRowView

**Files:**
- Create: `Vibecast/Views/EpisodeRowView.swift`

Used directly in the Podcast Detail sheet. Shows release date, title (with listened-state typography), description (hidden via `ViewThatFits` when the title needs two lines), and the `PlayControlView`.

- [ ] **Step 1: Create `EpisodeRowView.swift`**

  ```swift
  // Vibecast/Views/EpisodeRowView.swift
  import SwiftUI

  struct EpisodeRowView: View {
      let episode: Episode
      let onPlay: () -> Void

      private var titleWeight: Font.Weight {
          episode.listenedStatus == .unplayed ? .bold : .regular
      }

      private var titleColor: Color {
          episode.listenedStatus == .unplayed ? .primary : .secondary
      }

      private var relativeDate: String {
          let f = RelativeDateTimeFormatter()
          f.unitsStyle = .abbreviated
          return f.localizedString(for: episode.publishDate, relativeTo: .now)
      }

      var body: some View {
          HStack(alignment: .center, spacing: 12) {
              // Metadata — uses ViewThatFits to hide description when title wraps
              ViewThatFits(in: .vertical) {
                  // Preferred: date + title + description
                  VStack(alignment: .leading, spacing: 3) {
                      dateLabel
                      titleLabel
                      descriptionLabel
                  }
                  // Fallback: date + title only (title wrapped to 2 lines)
                  VStack(alignment: .leading, spacing: 3) {
                      dateLabel
                      titleLabel
                  }
              }

              Spacer(minLength: 8)

              PlayControlView(episode: episode, onTap: onPlay)
          }
          .frame(minHeight: 72)
      }

      private var dateLabel: some View {
          HStack(spacing: 4) {
              Text(relativeDate)
              if episode.isExplicit {
                  Text("E")
                      .padding(.horizontal, 3)
                      .background(Color.secondary.opacity(0.2), in: RoundedRectangle(cornerRadius: 2))
              }
              if episode.listenedStatus == .played {
                  Image(systemName: "checkmark")
              }
          }
          .font(.system(size: 10))
          .foregroundStyle(.tertiary)
      }

      private var titleLabel: some View {
          Text(episode.title)
              .font(.system(size: 14, weight: titleWeight))
              .foregroundStyle(titleColor)
              .lineLimit(2)
      }

      private var descriptionLabel: some View {
          Text(episode.descriptionText)
              .font(.system(size: 12))
              .foregroundStyle(.tertiary)
              .lineLimit(1)
      }
  }

  #Preview {
      let container = SampleData.container
      let episodes = try! ModelContext(container).fetch(
          FetchDescriptor<Episode>(sortBy: [SortDescriptor(\.publishDate, order: .reverse)])
      )
      return List {
          ForEach(episodes.prefix(6)) { ep in
              EpisodeRowView(episode: ep, onPlay: {})
                  .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14))
          }
      }
      .modelContainer(container)
  }
  ```

- [ ] **Step 2: Verify in Xcode canvas**

  Expected: bold titles for unplayed, lighter for played/in-progress. Description disappears on rows with long titles.

- [ ] **Step 3: Commit**

  ```bash
  git add Vibecast/Views/EpisodeRowView.swift
  git commit -m "feat: add EpisodeRowView with listened-state typography"
  ```

---

## Task 6: PodcastRowView

**Files:**
- Create: `Vibecast/Views/PodcastRowView.swift`

Displays podcast artwork alongside the latest episode's metadata and play control. Artwork and the metadata area are separate tap targets: both open the detail sheet. The play control is a third independent tap target.

- [ ] **Step 1: Create `PodcastRowView.swift`**

  ```swift
  // Vibecast/Views/PodcastRowView.swift
  import SwiftUI

  struct PodcastRowView: View {
      let podcast: Podcast
      let onPlay: () -> Void
      let onOpenDetail: () -> Void

      private var latestEpisode: Episode? {
          podcast.episodes.sorted { $0.publishDate > $1.publishDate }.first
      }

      var body: some View {
          HStack(alignment: .center, spacing: 12) {
              // Artwork — tapping opens detail
              artworkView
                  .onTapGesture { onOpenDetail() }

              if let episode = latestEpisode {
                  // Metadata area — tapping opens detail
                  episodeMetadata(episode: episode)
                      .contentShape(Rectangle())
                      .onTapGesture { onOpenDetail() }

                  // Play control — independent tap target
                  PlayControlView(episode: episode, onTap: onPlay)
              } else {
                  Text("No episodes")
                      .font(.system(size: 13))
                      .foregroundStyle(.tertiary)
              }
          }
          .padding(.vertical, 4)
      }

      private var artworkView: some View {
          RoundedRectangle(cornerRadius: 10)
              .fill(Color.secondary.opacity(0.25))
              .frame(width: 52, height: 52)
              .overlay {
                  if let urlString = podcast.artworkURL,
                     let url = URL(string: urlString) {
                      AsyncImage(url: url) { img in
                          img.resizable().scaledToFill()
                      } placeholder: {
                          Color.clear
                      }
                      .clipShape(RoundedRectangle(cornerRadius: 10))
                  } else {
                      Image(systemName: "mic.fill")
                          .foregroundStyle(.tertiary)
                  }
              }
      }

      private func episodeMetadata(episode: Episode) -> some View {
          ViewThatFits(in: .vertical) {
              VStack(alignment: .leading, spacing: 3) {
                  dateLabel(episode: episode)
                  titleLabel(episode: episode)
                  descriptionLabel(episode: episode)
              }
              VStack(alignment: .leading, spacing: 3) {
                  dateLabel(episode: episode)
                  titleLabel(episode: episode)
              }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      private func dateLabel(episode: Episode) -> some View {
          let f = RelativeDateTimeFormatter()
          f.unitsStyle = .abbreviated
          let relative = f.localizedString(for: episode.publishDate, relativeTo: .now)
          return HStack(spacing: 4) {
              Text(relative)
              if episode.isExplicit {
                  Text("E")
                      .padding(.horizontal, 3)
                      .background(Color.secondary.opacity(0.2), in: RoundedRectangle(cornerRadius: 2))
              }
              if episode.listenedStatus == .played {
                  Image(systemName: "checkmark")
              }
          }
          .font(.system(size: 10))
          .foregroundStyle(.tertiary)
      }

      private func titleLabel(episode: Episode) -> some View {
          Text(episode.title)
              .font(.system(size: 14, weight: episode.listenedStatus == .unplayed ? .bold : .regular))
              .foregroundStyle(episode.listenedStatus == .unplayed ? Color.primary : Color.secondary)
              .lineLimit(2)
      }

      private func descriptionLabel(episode: Episode) -> some View {
          Text(episode.descriptionText)
              .font(.system(size: 12))
              .foregroundStyle(.tertiary)
              .lineLimit(1)
      }
  }

  #Preview {
      let container = SampleData.container
      let podcasts = try! ModelContext(container).fetch(
          FetchDescriptor<Podcast>(sortBy: [SortDescriptor(\.sortPosition)])
      )
      return List {
          ForEach(podcasts) { podcast in
              PodcastRowView(podcast: podcast, onPlay: {}, onOpenDetail: {})
                  .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14))
          }
      }
      .modelContainer(container)
  }
  ```

- [ ] **Step 2: Verify in Xcode canvas**

  Expected: 5 rows, each with artwork placeholder, episode metadata in correct weight, play ring in correct state.

- [ ] **Step 3: Commit**

  ```bash
  git add Vibecast/Views/PodcastRowView.swift
  git commit -m "feat: add PodcastRowView with split artwork and play tap targets"
  ```

---

## Task 7: SubscriptionsViewModel + SubscriptionsListView

**Files:**
- Create: `Vibecast/ViewModels/SubscriptionsViewModel.swift`
- Create: `Vibecast/Views/SubscriptionsListView.swift`
- Modify: `Vibecast/VibecastApp.swift`
- Create: `VibecastTests/SubscriptionsViewModelTests.swift`

- [ ] **Step 1: Write failing ViewModel tests**

  Create `VibecastTests/SubscriptionsViewModelTests.swift`:

  ```swift
  import XCTest
  import SwiftData
  @testable import Vibecast

  @MainActor
  final class SubscriptionsViewModelTests: XCTestCase {
      var container: ModelContainer!
      var context: ModelContext!

      override func setUp() async throws {
          let config = ModelConfiguration(isStoredInMemoryOnly: true)
          container = try ModelContainer(for: Podcast.self, Episode.self, configurations: config)
          context = ModelContext(container)
          SampleData.insertSampleData(into: context)
      }

      func test_podcasts_sortedBySortPosition() throws {
          let vm = SubscriptionsViewModel(modelContext: context)
          let positions = vm.podcasts.map(\.sortPosition)
          XCTAssertEqual(positions, positions.sorted())
      }

      func test_remove_decreasesCount() throws {
          let vm = SubscriptionsViewModel(modelContext: context)
          let before = vm.podcasts.count
          vm.remove(vm.podcasts[0])
          XCTAssertEqual(vm.podcasts.count, before - 1)
      }

      func test_markPlayed_setsStatusToPlayed() throws {
          let vm = SubscriptionsViewModel(modelContext: context)
          let episode = vm.podcasts[0].episodes[0]
          vm.markPlayed(episode)
          XCTAssertEqual(episode.listenedStatus, .played)
          XCTAssertEqual(episode.playbackPosition, Double(episode.durationSeconds))
      }

      func test_move_reassignsSortPositionsSequentially() throws {
          let vm = SubscriptionsViewModel(modelContext: context)
          vm.move(from: IndexSet(integer: 0), to: 3)
          let positions = vm.podcasts.map(\.sortPosition)
          XCTAssertEqual(positions, Array(0..<vm.podcasts.count))
      }

      func test_move_changesOrder() throws {
          let vm = SubscriptionsViewModel(modelContext: context)
          let originalFirst = vm.podcasts[0].title
          vm.move(from: IndexSet(integer: 0), to: 3)
          XCTAssertNotEqual(vm.podcasts[0].title, originalFirst)
      }
  }
  ```

- [ ] **Step 2: Run — verify failure**

  Cmd+U. Expected: `SubscriptionsViewModel` not found.

- [ ] **Step 3: Create `SubscriptionsViewModel.swift`**

  ```swift
  // Vibecast/ViewModels/SubscriptionsViewModel.swift
  import SwiftData
  import Observation

  @Observable
  final class SubscriptionsViewModel {
      private(set) var podcasts: [Podcast] = []
      private let modelContext: ModelContext

      init(modelContext: ModelContext) {
          self.modelContext = modelContext
          fetch()
      }

      func fetch() {
          let descriptor = FetchDescriptor<Podcast>(
              sortBy: [SortDescriptor(\.sortPosition)]
          )
          podcasts = (try? modelContext.fetch(descriptor)) ?? []
      }

      func remove(_ podcast: Podcast) {
          modelContext.delete(podcast)
          save()
          fetch()
      }

      func markPlayed(_ episode: Episode) {
          episode.listenedStatus = .played
          episode.playbackPosition = Double(episode.durationSeconds)
          save()
      }

      func move(from source: IndexSet, to destination: Int) {
          podcasts.move(fromOffsets: source, toOffset: destination)
          for (index, podcast) in podcasts.enumerated() {
              podcast.sortPosition = index
          }
          save()
      }

      private func save() {
          try? modelContext.save()
      }
  }
  ```

- [ ] **Step 4: Run — verify all 5 tests pass**

  Cmd+U. Expected: 5 tests pass.

- [ ] **Step 5: Create `SubscriptionsListView.swift`**

  ```swift
  // Vibecast/Views/SubscriptionsListView.swift
  import SwiftUI
  import SwiftData

  struct SubscriptionsListView: View {
      @Environment(\.modelContext) private var modelContext
      @State private var viewModel: SubscriptionsViewModel?
      @State private var selectedPodcast: Podcast?
      @State private var showAddPodcast = false

      private var vm: SubscriptionsViewModel {
          guard let viewModel else {
              let v = SubscriptionsViewModel(modelContext: modelContext)
              return v
          }
          return viewModel
      }

      var body: some View {
          NavigationStack {
              List {
                  ForEach(vm.podcasts) { podcast in
                      PodcastRowView(
                          podcast: podcast,
                          onPlay: { /* Plan 2: start audio playback */ },
                          onOpenDetail: { selectedPodcast = podcast }
                      )
                      .listRowSeparator(.visible)
                      .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14))
                      .swipeActions(edge: .leading, allowsFullSwipe: true) {
                          Button {
                              if let ep = podcast.episodes
                                  .sorted(by: { $0.publishDate > $1.publishDate }).first {
                                  vm.markPlayed(ep)
                              }
                          } label: {
                              Label("Played", systemImage: "checkmark")
                          }
                          .tint(.green)
                      }
                      .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                          Button(role: .destructive) {
                              vm.remove(podcast)
                          } label: {
                              Label("Remove", systemImage: "trash")
                          }
                      }
                  }
                  .onMove { source, destination in
                      vm.move(from: source, to: destination)
                  }
              }
              .listStyle(.plain)
              .environment(\.editMode, .constant(.active))
              .navigationTitle("Vibecast")
              .toolbar {
                  ToolbarItem(placement: .navigationBarTrailing) {
                      Button {
                          showAddPodcast = true
                      } label: {
                          Image(systemName: "plus")
                              .font(.title2.weight(.light))
                      }
                  }
              }
              .sheet(item: $selectedPodcast) { podcast in
                  PodcastDetailView(podcast: podcast)
              }
          }
          .onAppear {
              if viewModel == nil {
                  viewModel = SubscriptionsViewModel(modelContext: modelContext)
              }
          }
      }
  }

  #Preview {
      SubscriptionsListView()
          .modelContainer(SampleData.container)
  }
  ```

  > The list is kept in `.active` edit mode permanently so long-press drag handles are always present. Plan 2 replaces this with a long-press gesture that activates drag without showing the edit-mode indent and delete buttons.

- [ ] **Step 6: Update `VibecastApp.swift` to use `SubscriptionsListView`**

  ```swift
  // Vibecast/VibecastApp.swift
  import SwiftUI
  import SwiftData

  @main
  struct VibecastApp: App {
      var body: some Scene {
          WindowGroup {
              SubscriptionsListView()
          }
          .modelContainer(for: [Podcast.self, Episode.self])
      }
  }
  ```

- [ ] **Step 7: Run on simulator and manually verify each gesture**

  Cmd+R with iPhone 15 Pro simulator.

  | Action | Expected result |
  |---|---|
  | App launch | 5 podcast rows visible, varied play states |
  | Swipe row right | Green "Played" action appears |
  | Confirm "Played" | Row title de-emphasises, ring fills |
  | Swipe row left | Red "Remove" appears |
  | Confirm "Remove" | Row disappears |
  | Long-press and drag | Row lifts, drag to new position |
  | Release | Order persists after scroll |
  | Tap `+` | Empty area (no crash) |

- [ ] **Step 8: Commit**

  ```bash
  git add Vibecast/ViewModels/SubscriptionsViewModel.swift Vibecast/Views/SubscriptionsListView.swift Vibecast/VibecastApp.swift VibecastTests/SubscriptionsViewModelTests.swift
  git commit -m "feat: add SubscriptionsListView with swipe and reorder gestures"
  ```

---

## Task 8: PodcastDetailView

**Files:**
- Create: `Vibecast/ViewModels/PodcastDetailViewModel.swift`
- Create: `Vibecast/Views/PodcastDetailView.swift`

- [ ] **Step 1: Create `PodcastDetailViewModel.swift`**

  ```swift
  // Vibecast/ViewModels/PodcastDetailViewModel.swift
  import Observation

  @Observable
  final class PodcastDetailViewModel {
      private let podcast: Podcast
      private let pageSize = 10
      private lazy var allEpisodes: [Episode] = {
          podcast.episodes.sorted { $0.publishDate > $1.publishDate }
      }()

      private(set) var displayedEpisodes: [Episode] = []
      private(set) var isLoadingMore = false

      var hasMore: Bool { displayedEpisodes.count < allEpisodes.count }
      var podcastTitle: String { podcast.title }
      var podcastAuthor: String { podcast.author }
      var podcastArtworkURL: String? { podcast.artworkURL }

      init(podcast: Podcast) {
          self.podcast = podcast
          loadNextPage()
      }

      func loadNextPage() {
          guard !isLoadingMore, hasMore else { return }
          isLoadingMore = true
          let start = displayedEpisodes.count
          let end = min(start + pageSize, allEpisodes.count)
          displayedEpisodes.append(contentsOf: allEpisodes[start..<end])
          isLoadingMore = false
      }
  }
  ```

- [ ] **Step 2: Create `PodcastDetailView.swift`**

  ```swift
  // Vibecast/Views/PodcastDetailView.swift
  import SwiftUI

  struct PodcastDetailView: View {
      let podcast: Podcast
      @State private var viewModel: PodcastDetailViewModel?

      private var vm: PodcastDetailViewModel {
          viewModel ?? PodcastDetailViewModel(podcast: podcast)
      }

      var body: some View {
          NavigationStack {
              List {
                  podcastHeader
                      .listRowSeparator(.hidden)

                  ForEach(vm.displayedEpisodes) { episode in
                      EpisodeRowView(episode: episode, onPlay: { /* Plan 2 */ })
                          .listRowSeparator(.visible)
                          .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14))
                          .onAppear {
                              if episode.id == vm.displayedEpisodes.last?.id && vm.hasMore {
                                  vm.loadNextPage()
                              }
                          }
                  }

                  if vm.isLoadingMore {
                      ProgressView()
                          .frame(maxWidth: .infinity)
                          .listRowSeparator(.hidden)
                  }
              }
              .listStyle(.plain)
              .navigationTitle(podcast.title)
              .navigationBarTitleDisplayMode(.inline)
          }
          .presentationDetents([.large])
          .presentationDragIndicator(.visible)
          .onAppear {
              if viewModel == nil {
                  viewModel = PodcastDetailViewModel(podcast: podcast)
              }
          }
      }

      private var podcastHeader: some View {
          HStack(alignment: .top, spacing: 14) {
              RoundedRectangle(cornerRadius: 12)
                  .fill(Color.secondary.opacity(0.2))
                  .frame(width: 88, height: 88)
                  .overlay {
                      Image(systemName: "mic.fill")
                          .font(.title2)
                          .foregroundStyle(.tertiary)
                  }

              VStack(alignment: .leading, spacing: 5) {
                  Text(podcast.title)
                      .font(.headline)
                  Text(podcast.author)
                      .font(.subheadline)
                      .foregroundStyle(.secondary)
              }

              Spacer()
          }
          .padding(.vertical, 8)
      }
  }

  #Preview {
      let container = SampleData.container
      let podcasts = try! ModelContext(container).fetch(
          FetchDescriptor<Podcast>(sortBy: [SortDescriptor(\.sortPosition)])
      )
      return PodcastDetailView(podcast: podcasts[0])
          .modelContainer(container)
  }
  ```

- [ ] **Step 3: Run on simulator and verify the detail sheet**

  Tap a podcast row's artwork or title. Expected:
  - Sheet slides up with drag handle at top
  - Header shows artwork placeholder, podcast title, author
  - First 10 episodes listed with correct play states
  - Scrolling to the bottom triggers the next 10 to load
  - Swipe down dismisses the sheet

- [ ] **Step 4: Commit**

  ```bash
  git add Vibecast/ViewModels/PodcastDetailViewModel.swift Vibecast/Views/PodcastDetailView.swift
  git commit -m "feat: add PodcastDetailView with paginated episode list"
  ```

---

## Task 9: Push to Remote

- [ ] **Step 1: Confirm all tests pass**

  Cmd+U. Expected: 10 tests pass, 0 failures.

- [ ] **Step 2: Push**

  ```bash
  git push
  ```

- [ ] **Step 3: Verify on GitHub**

  Confirm the file tree on GitHub includes `Vibecast/Models/`, `Vibecast/Views/`, `Vibecast/ViewModels/`, `VibecastTests/`.
