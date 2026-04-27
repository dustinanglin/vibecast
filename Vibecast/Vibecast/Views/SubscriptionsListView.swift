import SwiftUI
import SwiftData

struct SubscriptionsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.playerManager) private var playerManager
    @Environment(\.subscriptionManager) private var subscriptionManager
    @State private var viewModel: SubscriptionsViewModel?
    @State private var selectedPodcast: Podcast?
    @State private var showAddPodcast = false
    @State private var showFullScreenPlayer = false

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    listContent(viewModel: viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Vibecast")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
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
            .sheet(isPresented: $showFullScreenPlayer) {
                if let playerManager, playerManager.currentEpisode != nil {
                    FullScreenPlayerView(player: playerManager)
                }
            }
            .sheet(isPresented: $showAddPodcast) {
                if let subscriptionManager {
                    AddPodcastSheet(manager: subscriptionManager)
                }
            }
            .onChange(of: showAddPodcast) { _, isPresented in
                if !isPresented {
                    viewModel?.fetch()
                }
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
        .task {
            if viewModel == nil {
                viewModel = SubscriptionsViewModel(modelContext: modelContext)
            }
        }
    }

    @ViewBuilder
    private func listContent(viewModel vm: SubscriptionsViewModel) -> some View {
        if vm.podcasts.isEmpty {
            ContentUnavailableView(
                "No podcasts yet",
                systemImage: "antenna.radiowaves.left.and.right",
                description: Text("Tap + to search for podcasts or import an OPML file.")
            )
        } else {
            List {
                ForEach(vm.podcasts) { podcast in
                    let latest = podcast.episodes.sorted(by: { $0.publishDate > $1.publishDate }).first
                    let isCurrent = latest != nil && latest?.persistentModelID == playerManager?.currentEpisode?.persistentModelID
                    PodcastRowView(
                        podcast: podcast,
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
        }
    }
}

#Preview {
    SubscriptionsListView()
        .modelContainer(SampleData.container)
}
