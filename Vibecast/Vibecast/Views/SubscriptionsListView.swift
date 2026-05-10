import SwiftUI
import SwiftData

struct SubscriptionsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.playerManager) private var playerManager
    @Environment(\.subscriptionManager) private var subscriptionManager
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: [SortDescriptor(\Podcast.sortPosition)]) private var podcasts: [Podcast]
    @Query(sort: [SortDescriptor(\Vibe.sortPosition)]) private var vibes: [Vibe]
    @State private var activeVibe: Vibe?
    @State private var toastCenter = ToastCenter()
    @State private var addToVibe: Vibe?

    @State private var selectedPodcast: Podcast?
    @State private var showAddSheet = false
    @State private var showFullScreenPlayer = false
    @State private var pendingDeletes: Set<PersistentIdentifier> = []
    @State private var editMode: EditMode = .inactive

    var body: some View {
        NavigationStack {
            List {
                VibeMasthead(
                    vibes: vibes,
                    activeVibe: $activeVibe,
                    onStartVibe: { vibe in
                        guard let mgr = playerManager else { return }
                        if mgr.startVibe(vibe) == .allCaughtUp {
                            toastCenter.show("All caught up on this vibe")
                        }
                    },
                    onTapStack: { /* TODO(plan-7-task-13): present ManageVibesView */ },
                    onTapAdd: { showAddSheet = true }
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Brand.Color.bg)
                .listRowSeparator(.hidden)
                .moveDisabled(true)
                .deleteDisabled(true)

                if activeVibe == nil {
                    sectionLabel
                        .listRowInsets(EdgeInsets(top: 4, leading: 22, bottom: 8, trailing: 22))
                        .listRowBackground(Brand.Color.bg)
                        .listRowSeparator(.hidden)
                        .moveDisabled(true)
                        .deleteDisabled(true)
                }

                if filteredPodcasts.isEmpty {
                    if let active = activeVibe {
                        AddShowGhostRow(vibeColorKey: active.colorKey, action: {
                            addToVibe = active
                        })
                        .listRowInsets(EdgeInsets(top: 30, leading: 22, bottom: 30, trailing: 22))
                        .listRowBackground(Brand.Color.bg)
                        .listRowSeparator(.hidden)
                    } else {
                        emptyStateRow
                            .listRowInsets(EdgeInsets(top: 60, leading: 22, bottom: 60, trailing: 22))
                            .listRowBackground(Brand.Color.bg)
                            .listRowSeparator(.hidden)
                    }
                } else {
                    ForEach(filteredPodcasts) { podcast in
                        let snapshot = PodcastRowSnapshot(podcast)
                        let dots = activeVibe == nil ? snapshot.vibeColorKeys : []
                        let latest = podcast.episodes.sorted(by: { $0.publishDate > $1.publishDate }).first
                        let isCurrent = latest != nil && latest?.persistentModelID == playerManager?.currentEpisode?.persistentModelID
                        PodcastRowView(
                            snapshot: snapshot,
                            isCurrent: isCurrent,
                            isPlaying: isCurrent && (playerManager?.isPlaying ?? false),
                            vibeDots: dots,
                            onPlay: {
                                guard let ep = latest, let mgr = playerManager else { return }
                                if let active = activeVibe {
                                    if mgr.startVibe(active, from: podcast) == .allCaughtUp {
                                        toastCenter.show("All caught up on this vibe")
                                    }
                                } else if mgr.currentEpisode?.persistentModelID == ep.persistentModelID {
                                    mgr.togglePlayPause()
                                } else {
                                    mgr.play(ep)
                                }
                            },
                            onOpenDetail: { selectedPodcast = podcast }
                        )
                        .listRowBackground(Brand.Color.bg)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 14))
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                if let ep = podcast.episodes
                                    .sorted(by: { $0.publishDate > $1.publishDate }).first {
                                    snapAfterCollapse { markPlayed(ep) }
                                }
                            } label: {
                                Label("Played", systemImage: "checkmark")
                            }
                            .tint(.green)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            // Debug-affordance: reset the latest episode to unplayed
                            // (declared first so it sits at the trailing edge, to the
                            // right of Remove). May be removed once we have a more
                            // intentional "reset progress" affordance in detail view.
                            Button {
                                if let ep = podcast.episodes
                                    .sorted(by: { $0.publishDate > $1.publishDate }).first {
                                    snapAfterCollapse { markUnplayed(ep) }
                                }
                            } label: {
                                Label("Unplayed", systemImage: "arrow.uturn.backward")
                            }
                            .tint(.blue)

                            Button(role: .destructive) {
                                remove(podcast)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                    .onMove { source, destination in
                        // Reorder is only meaningful on the All view (per-vibe ordering
                        // is not user-editable in v1). Limit by setting moveDisabled at
                        // the row level when activeVibe != nil.
                        guard activeVibe == nil else { return }
                        move(from: source, to: destination)
                    }
                    // Trailing add-show ghost row when in a non-empty vibe.
                    if let active = activeVibe {
                        AddShowGhostRow(vibeColorKey: active.colorKey, action: {
                            addToVibe = active
                        })
                        .listRowInsets(EdgeInsets(top: 12, leading: 22, bottom: 12, trailing: 22))
                        .listRowBackground(Brand.Color.bg)
                        .listRowSeparator(.hidden)
                        .moveDisabled(true)
                        .deleteDisabled(true)
                    }
                }

                // Reserve scroll-tail so the last row isn't permanently
                // hidden behind the floating mini-player bar.
                if playerManager?.currentEpisode != nil {
                    Color.clear
                        .frame(height: 80)
                        .listRowBackground(Brand.Color.bg)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                        .moveDisabled(true)
                        .deleteDisabled(true)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Brand.Color.bg)
            .environment(\.editMode, $editMode)
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await subscriptionManager?.refreshAllIfStale() }
            }
            .refreshable {
                await subscriptionManager?.refreshAll()
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
        }
        // Floating overlay (not safeAreaInset) so List content scrolls *under*
        // the bar, giving the translucent paper a real "tracing paper" effect.
        // Each List adds a transparent footer row when a player is loaded,
        // so the bottom rows aren't permanently hidden behind the bar.
        .overlay(alignment: .bottom) {
            if let playerManager, playerManager.currentEpisode != nil {
                MiniPlayerBar(
                    player: playerManager,
                    onTapBar: { showFullScreenPlayer = true }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .overlay(alignment: .bottom) {
            if let message = toastCenter.current {
                ToastView(
                    message: message,
                    bottomInset: playerManager?.currentEpisode != nil ? 88 : 24
                )
            }
        }
        .environment(\.toastCenter, toastCenter)
    }

    // MARK: - Section label (count · MOST RECENT ——— EDIT ORDER)

    private var sectionLabel: some View {
        HStack(spacing: 10) {
            Text(sectionLabelText)
                .font(Brand.Font.monoEyebrow())
                .tracking(Brand.Layout.monoTracking)
                .foregroundStyle(Brand.Color.inkMuted)
                .fixedSize(horizontal: true, vertical: false)
            Rectangle()
                .fill(Brand.Color.inkHairline)
                .frame(height: Brand.Layout.hairlineWidth)
                .frame(maxWidth: .infinity)
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    editMode = editMode.isEditing ? .inactive : .active
                }
            } label: {
                Text(editMode.isEditing ? "DONE" : "EDIT ORDER")
                    .font(Brand.Font.monoEyebrow())
                    .tracking(Brand.Layout.monoTracking)
                    .foregroundStyle(editMode.isEditing ? Brand.Color.accent : Brand.Color.inkMuted)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .buttonStyle(.plain)
            .disabled(visiblePodcasts.isEmpty && !editMode.isEditing)
            .accessibilityLabel(editMode.isEditing ? "Done editing order" : "Edit subscription order")
        }
    }

    private var sectionLabelText: String {
        let count = visiblePodcasts.count
        let countLabel = count == 1 ? "1 SHOW" : "\(count) SHOWS"
        return "\(countLabel) · YOUR ORDER"
    }

    // MARK: - Empty state row (lives inside the List so masthead always shows)

    private var emptyStateRow: some View {
        VStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Brand.Color.accent)
            Text("No podcasts yet")
                .font(Brand.Font.serifSubtitle())
                .foregroundStyle(Brand.Color.ink)
            Text("Tap + above to search or import an OPML file.")
                .font(Brand.Font.uiBody())
                .foregroundStyle(Brand.Color.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Computed podcast lists

    private var visiblePodcasts: [Podcast] {
        podcasts.filter { !pendingDeletes.contains($0.persistentModelID) }
    }

    private var filteredPodcasts: [Podcast] {
        guard let active = activeVibe else { return visiblePodcasts }
        let memberships = active.memberships.sorted(by: { $0.position < $1.position })
        let podcasts = memberships.compactMap { $0.podcast }
        return podcasts.filter { !pendingDeletes.contains($0.persistentModelID) }
    }

    // MARK: - Actions

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
        if let mgr = playerManager {
            mgr.markPlayed(episode)
        } else {
            episode.listenedStatus = .played
            episode.playbackPosition = Double(episode.durationSeconds)
            try? modelContext.save()
        }
    }

    private func markUnplayed(_ episode: Episode) {
        episode.listenedStatus = .unplayed
        episode.playbackPosition = 0
        try? modelContext.save()
    }

    /// Wait for the swipe-action's collapse to complete, then snap-mutate
    /// (no animation) so the new row state appears the instant the row
    /// returns to its resting position. Avoids the cross-fade phantom that
    /// happens when a state-driven opacity change overlaps the system
    /// collapse animation.
    private func snapAfterCollapse(_ mutate: @escaping () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                mutate()
            }
        }
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
