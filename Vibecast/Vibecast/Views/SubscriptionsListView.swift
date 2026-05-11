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
    @State private var showManageVibes = false
    @State private var showFullScreenPlayer = false
    @State private var pendingDeletes: Set<PersistentIdentifier> = []
    @State private var editMode: EditMode = .inactive

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Vibe color band layered behind the List so it can bleed
                // past the top safe area into the status-bar / camera-pill
                // region. Height covers the masthead + safe-area top with
                // some headroom; the gradient fades to transparent so the
                // List's paper-warm bg shows through below the masthead.
                if let active = activeVibe {
                    LinearGradient(
                        colors: [active.colorKey.chip, Brand.Color.bg.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 380)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .ignoresSafeArea(edges: .top)
                    .animation(.easeInOut(duration: 0.28), value: activeVibe)
                    .transition(.opacity)
                }

                List {
                    VibeMasthead(
                    vibes: vibes,
                    activeVibe: $activeVibe,
                    queueSourceVibe: playerManager?.queueSourceVibe,
                    isPlaying: playerManager?.isPlaying ?? false,
                    onStartVibe: { vibe in
                        guard let mgr = playerManager else { return }
                        if mgr.startVibe(vibe) == .allCaughtUp {
                            toastCenter.show("All caught up on this vibe")
                        }
                    },
                    onStartAll: { startNextUnplayed() },
                    onToggleVibe: { playerManager?.togglePlayPause() },
                    onTapStack: { showManageVibes = true },
                    onTapAdd: { showAddSheet = true }
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Brand.Color.bg)
                .listRowSeparator(.hidden)
                .moveDisabled(true)
                .deleteDisabled(true)

                sectionLabel
                    .listRowInsets(EdgeInsets(top: 4, leading: 22, bottom: 8, trailing: 22))
                    .listRowBackground(Brand.Color.bg)
                    .listRowSeparator(.hidden)
                    .moveDisabled(true)
                    .deleteDisabled(true)

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
                    ForEach(Array(filteredPodcasts.enumerated()), id: \.element.persistentModelID) { index, podcast in
                        // In a vibe view, use the per-vibe ordinal so the left-slot
                        // number reflects "this vibe's order" rather than leaking
                        // the global library sortPosition.
                        let positionOverride = activeVibe == nil ? nil : index + 1
                        let snapshot = PodcastRowSnapshot(podcast, position: positionOverride)
                        let dots = activeVibe == nil ? snapshot.vibeColorKeys : []
                        let latest = podcast.episodes.sorted(by: { $0.publishDate > $1.publishDate }).first
                        // The row is "current" only while there's something playable
                        // happening with this episode. Once it's been played to the
                        // end (and the player isn't actively playing), revert to
                        // played-row treatment — the mini-player still holds the
                        // episode loaded for one-tap replay, but the row shouldn't
                        // keep wearing the now-playing card.
                        let isCurrent: Bool = {
                            guard let latest = latest,
                                  let current = playerManager?.currentEpisode,
                                  latest.persistentModelID == current.persistentModelID else {
                                return false
                            }
                            if latest.listenedStatus == .played && !(playerManager?.isPlaying ?? false) {
                                return false
                            }
                            return true
                        }()
                        PodcastRowView(
                            snapshot: snapshot,
                            isCurrent: isCurrent,
                            isPlaying: isCurrent && (playerManager?.isPlaying ?? false),
                            vibeDots: dots,
                            nowPlayingTint: playerManager?.queueSourceVibe?.colorKey.band ?? Brand.Color.accent,
                            onPlay: {
                                guard let ep = latest, let mgr = playerManager else { return }
                                // If this row's latest episode is the currently-loaded
                                // one, the row's button is a play/pause toggle. Always
                                // adopt the current view as the queue source — All
                                // (nil) clears the source so advance walks global
                                // sortPosition; a vibe sets the source so advance
                                // walks that vibe. The masthead CTA reflects this on
                                // the next render ("Resume"/"Vibing" or "Start
                                // listening" accordingly).
                                if mgr.currentEpisode?.persistentModelID == ep.persistentModelID {
                                    mgr.adoptQueueSource(activeVibe)
                                    mgr.togglePlayPause()
                                    return
                                }
                                // Inside a vibe: play this episode as part of the vibe
                                // queue so the next end-of-episode advance walks the vibe.
                                // Played episodes replay from 0 (resetIfComplete) and
                                // still kick off the queue from here.
                                if let active = activeVibe {
                                    mgr.playEpisodeInVibe(ep, vibe: active)
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
                            // In a vibe view, the most natural curation action is
                            // "remove this from the vibe" — declared first so it
                            // sits at the trailing edge (most reachable). Hidden
                            // on All view since there's nothing to untag from.
                            if let active = activeVibe {
                                Button {
                                    snapAfterCollapse { removeFromVibe(podcast, vibe: active) }
                                } label: {
                                    Label("From Vibe", systemImage: "tag.slash")
                                }
                                .tint(.purple)
                            }

                            // Debug-affordance: reset the latest episode to unplayed.
                            // May be removed once we have a more intentional "reset
                            // progress" affordance in detail view.
                            Button {
                                if let ep = podcast.episodes
                                    .sorted(by: { $0.publishDate > $1.publishDate }).first {
                                    snapAfterCollapse { markUnplayed(ep) }
                                }
                            } label: {
                                Label("Unplayed", systemImage: "arrow.uturn.backward")
                            }
                            .tint(.blue)

                            // Unsubscribe is scoped to All view only — in a vibe
                            // view the user probably means "remove from this vibe"
                            // (the purple action above), so don't surface a button
                            // labelled "Remove" that actually deletes the entire
                            // subscription.
                            if activeVibe == nil {
                                Button(role: .destructive) {
                                    remove(podcast)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .onMove { source, destination in
                        if let active = activeVibe {
                            moveInVibe(active, from: source, to: destination)
                        } else {
                            move(from: source, to: destination)
                        }
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
            .onChange(of: activeVibe) { _, _ in
                // Switching the masthead context should drop the user out
                // of edit so the previous-view's drag handles disappear
                // before the new list lays out.
                if editMode.isEditing { editMode = .inactive }
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await subscriptionManager?.refreshAllIfStale() }
            }
            .refreshable {
                await subscriptionManager?.refreshAll()
            }
            .sheet(isPresented: $showManageVibes) {
                ManageVibesView()
            }
            .sheet(isPresented: $showAddSheet) {
                AddPodcastSheet()
            }
            .sheet(item: $addToVibe) { vibe in
                AddShowSheet(vibe: vibe)
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

    // MARK: - Section label ("N SHOWS · YOUR ORDER ——— EDIT ORDER")
    //
    // Identical format on All and vibe views. EDIT ORDER is always available;
    // the .onMove handler dispatches to global or per-vibe reorder based on
    // activeVibe (vibe identity itself is conveyed by the masthead eyebrow).

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
            .disabled(filteredPodcasts.isEmpty && !editMode.isEditing)
            .accessibilityLabel(editMode.isEditing ? "Done editing order" : "Edit order")
        }
    }

    private var sectionLabelText: String {
        let count = activeVibe == nil ? visiblePodcasts.count : filteredPodcasts.count
        let countLabel = count == 1 ? "1 SHOW" : "\(count) SHOWS"
        return "\(countLabel) · YOUR ORDER"
    }

    /// Start playback from the first podcast in global sort order whose
    /// latest episode hasn't been played. Falls back to a toast on empty.
    private func startNextUnplayed() {
        guard let mgr = playerManager else { return }
        for podcast in visiblePodcasts {
            let latest = podcast.episodes.sorted(by: { $0.publishDate > $1.publishDate }).first
            guard let episode = latest, episode.listenedStatus != .played else { continue }
            mgr.play(episode)
            return
        }
        toastCenter.show("All caught up")
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
        // Defensive: if the active vibe was deleted (we're inside the one-frame
        // window before VibeMasthead's .onChange resyncs activeVibe to the
        // vibe that now lives at this slot), return EMPTY rather than falling
        // through to visiblePodcasts. Showing the All-view library when the
        // masthead is showing a vibe is the wrong kind of mismatch.
        guard vibes.contains(where: { $0.persistentModelID == active.persistentModelID }) else {
            return []
        }
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

    /// Reorder podcasts within `vibe`. Rewrites every membership's `position`
    /// contiguously from 0 so the per-vibe ordering stays dense (no gaps from
    /// untag/retag history).
    private func moveInVibe(_ vibe: Vibe, from source: IndexSet, to destination: Int) {
        var reordered = vibe.memberships.sorted(by: { $0.position < $1.position })
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, membership) in reordered.enumerated() {
            membership.position = index
        }
        try? modelContext.save()
    }

    /// Untag `podcast` from `vibe` by deleting its membership. The podcast
    /// itself and its other vibe memberships survive.
    private func removeFromVibe(_ podcast: Podcast, vibe: Vibe) {
        guard let membership = podcast.vibeMemberships.first(where: {
            $0.vibe?.persistentModelID == vibe.persistentModelID
        }) else { return }
        modelContext.delete(membership)
        try? modelContext.save()
    }
}

#Preview {
    SubscriptionsListView()
        .modelContainer(SampleData.container)
}
