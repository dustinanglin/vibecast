import SwiftUI
import SwiftData

struct PodcastDetailView: View {
    let podcast: Podcast
    @Environment(\.playerManager) private var playerManager
    @Environment(\.subscriptionManager) private var subscriptionManager
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: PodcastDetailViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    listContent(viewModel: viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(podcast.title)
            .navigationBarTitleDisplayMode(.inline)
            .background(Brand.Color.bg)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task {
            if viewModel == nil {
                viewModel = PodcastDetailViewModel(podcast: podcast)
            }
            await subscriptionManager?.refresh(podcast)
            viewModel?.refetch()
        }
    }

    @ViewBuilder
    private func listContent(viewModel vm: PodcastDetailViewModel) -> some View {
        List {
            podcastHeader
                .listRowSeparator(.hidden)
                .listRowBackground(Brand.Color.bg)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

            PodcastDetailVibesSection(podcast: podcast)
                .listRowSeparator(.hidden)
                .listRowBackground(Brand.Color.bg)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

            sortEyebrow(viewModel: vm)
                .listRowSeparator(.hidden)
                .listRowBackground(Brand.Color.bg)
                .listRowInsets(EdgeInsets(top: 0, leading: 22, bottom: 0, trailing: 22))

            ForEach(vm.displayedEpisodes) { episode in
                let isCurrent = episode.persistentModelID == playerManager?.currentEpisode?.persistentModelID
                EpisodeRowView(
                    episode: episode,
                    isCurrent: isCurrent,
                    isPlaying: isCurrent && (playerManager?.isPlaying ?? false),
                    onPlay: {
                        guard let mgr = playerManager else { return }
                        if mgr.currentEpisode?.persistentModelID == episode.persistentModelID {
                            mgr.togglePlayPause()
                        } else {
                            mgr.play(episode)
                        }
                    }
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Brand.Color.bg)
                .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 14))
                .onAppear {
                    if episode.id == vm.displayedEpisodes.last?.id && vm.hasMore {
                        vm.loadNextPage()
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        snapAfterCollapse { markPlayed(episode) }
                    } label: {
                        Label("Played", systemImage: "checkmark")
                    }
                    .tint(.green)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        snapAfterCollapse { markUnplayed(episode) }
                    } label: {
                        Label("Unplayed", systemImage: "arrow.uturn.backward")
                    }
                    .tint(.blue)
                }
            }

            if vm.isLoadingMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Brand.Color.bg)
            }

            // Reserve scroll-tail so the last episode row isn't permanently
            // hidden behind the floating mini-player bar.
            if playerManager?.currentEpisode != nil {
                Color.clear
                    .frame(height: 80)
                    .listRowBackground(Brand.Color.bg)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
            }
        }
        .listStyle(.plain)
        .background(Brand.Color.bg)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Episode mutations (mirrors SubscriptionsListView, with
    // detail-view-appropriate auto-advance: walk down THIS podcast's
    // episode list rather than jumping to the next podcast).

    private func markPlayed(_ episode: Episode) {
        if let mgr = playerManager {
            mgr.markPlayed(episode, advance: .nextEpisodeInPodcast)
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
    /// (no animation). Same pattern as SubscriptionsListView — avoids the
    /// cross-fade phantom when an opacity-changing state transition overlaps
    /// the system swipe-collapse.
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

    /// Eyebrow row between the vibes section and the episode list. Mirrors
    /// the "IN YOUR VIBES" eyebrow style (mono caps, tracked, trailing
    /// hairline) and wraps a Menu so tapping anywhere on the row drops a
    /// chooser for the sort mode. The label changes with the current mode
    /// so the cap is always visible inline ("OLDEST FIRST · RECENT 25")
    /// without a separate help affordance.
    @ViewBuilder
    private func sortEyebrow(viewModel vm: PodcastDetailViewModel) -> some View {
        Menu {
            Picker("Sort", selection: Binding(
                get: { vm.sortOrder },
                set: { vm.setSortOrder($0) }
            )) {
                Text("Newest first").tag(EpisodeSortOrder.newest)
                Text("Oldest first · recent \(EpisodeSortOrder.oldestFirstCap)")
                    .tag(EpisodeSortOrder.oldest)
            }
        } label: {
            HStack(spacing: 6) {
                Text(sortEyebrowText(for: vm.sortOrder))
                    .font(Brand.Font.monoEyebrow())
                    .tracking(Brand.Layout.monoTracking)
                    .foregroundStyle(Brand.Color.inkMuted)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Brand.Color.inkMuted)
                Spacer()
                Rectangle()
                    .fill(Brand.Color.inkHairline)
                    .frame(height: Brand.Layout.hairlineWidth)
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Episode sort order, currently \(sortAccessibilityValue(for: vm.sortOrder))")
        .accessibilityHint("Double-tap to change sort order")
    }

    private func sortEyebrowText(for order: EpisodeSortOrder) -> String {
        switch order {
        case .newest: return "NEWEST FIRST"
        case .oldest: return "OLDEST FIRST · RECENT \(EpisodeSortOrder.oldestFirstCap)"
        }
    }

    private func sortAccessibilityValue(for order: EpisodeSortOrder) -> String {
        switch order {
        case .newest: return "newest first"
        case .oldest: return "oldest first, recent \(EpisodeSortOrder.oldestFirstCap) episodes"
        }
    }

    private var podcastHeader: some View {
        VStack(alignment: .center, spacing: 12) {
            CoverArtwork(
                urlString: podcast.artworkURL,
                title: podcast.title,
                size: 120,
                radius: Brand.Radius.coverMedium
            )

            VStack(alignment: .center, spacing: 4) {
                Text(podcast.author)
                    .font(Brand.Font.monoEyebrowLarge())
                    .tracking(Brand.Layout.monoTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(Brand.Color.inkSecondary)
                    .lineLimit(1)

                Text(podcast.title)
                    .font(Brand.Font.serifTitle(size: 28))
                    .foregroundStyle(Brand.Color.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
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
