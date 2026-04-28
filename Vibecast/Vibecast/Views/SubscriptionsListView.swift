import SwiftUI
import SwiftData

struct SubscriptionsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.playerManager) private var playerManager
    @Environment(\.subscriptionManager) private var subscriptionManager
    @Query(sort: [SortDescriptor(\Podcast.sortPosition)]) private var podcasts: [Podcast]

    @State private var selectedPodcast: Podcast?
    @State private var showAddSheet = false
    @State private var showFullScreenPlayer = false
    @State private var pendingDeletes: Set<PersistentIdentifier> = []

    var body: some View {
        NavigationStack {
            listContent
                .navigationTitle("Subscriptions")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        EditButton()
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showAddSheet = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.title2.weight(.light))
                        }
                    }
                }
                .sheet(isPresented: $showAddSheet) {
                    AddPodcastSheet()
                }
                .sheet(isPresented: $showFullScreenPlayer) {
                    if let playerManager, playerManager.currentEpisode != nil {
                        FullScreenPlayerView(player: playerManager)
                    }
                }
                .navigationDestination(item: $selectedPodcast) { podcast in
                    PodcastDetailView(podcast: podcast)
                }
                .safeAreaInset(edge: .bottom) {
                    if let playerManager, playerManager.currentEpisode != nil {
                        MiniPlayerBar(
                            player: playerManager,
                            onTapBar: { showFullScreenPlayer = true }
                        )
                    }
                }
        }
    }

    private var visiblePodcasts: [Podcast] {
        podcasts.filter { !pendingDeletes.contains($0.persistentModelID) }
    }

    @ViewBuilder
    private var listContent: some View {
        if podcasts.isEmpty {
            ContentUnavailableView(
                "No podcasts yet",
                systemImage: "antenna.radiowaves.left.and.right",
                description: Text("Tap + to search for podcasts or import an OPML file.")
            )
        } else {
            List {
                ForEach(visiblePodcasts) { podcast in
                    let snapshot = PodcastRowSnapshot(podcast)
                    let latest = podcast.episodes.sorted(by: { $0.publishDate > $1.publishDate }).first
                    let isCurrent = latest != nil && latest?.persistentModelID == playerManager?.currentEpisode?.persistentModelID
                    PodcastRowView(
                        snapshot: snapshot,
                        isCurrent: isCurrent,
                        isPlaying: isCurrent && (playerManager?.isPlaying ?? false),
                        onPlay: {
                            guard let ep = latest, let mgr = playerManager else { return }
                            if mgr.currentEpisode?.persistentModelID == ep.persistentModelID {
                                mgr.togglePlayPause()
                            } else {
                                mgr.play(ep)
                            }
                        },
                        onOpenDetail: { selectedPodcast = podcast }
                    )
                    .listRowSeparator(.visible)
                    .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14))
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            if let ep = podcast.episodes
                                .sorted(by: { $0.publishDate > $1.publishDate }).first {
                                markPlayed(ep)
                            }
                        } label: {
                            Label("Played", systemImage: "checkmark")
                        }
                        .tint(.green)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            remove(podcast)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
                .onMove { source, destination in
                    move(from: source, to: destination)
                }
            }
            .listStyle(.plain)
            .refreshable {
                await subscriptionManager?.refreshAll()
            }
        }
    }

    private func remove(_ podcast: Podcast) {
        let id = podcast.persistentModelID
        pendingDeletes.insert(id)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            modelContext.delete(podcast)
            try? modelContext.save()
            pendingDeletes.remove(id)
        }
    }

    private func markPlayed(_ episode: Episode) {
        episode.listenedStatus = .played
        episode.playbackPosition = Double(episode.durationSeconds)
        try? modelContext.save()
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = podcasts
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, podcast) in reordered.enumerated() {
            podcast.sortPosition = index
        }
        try? modelContext.save()
    }
}

#Preview {
    SubscriptionsListView()
        .modelContainer(SampleData.container)
}
