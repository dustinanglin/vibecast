import SwiftUI
import SwiftData

struct SubscriptionsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.playerManager) private var playerManager
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
        List {
            ForEach(vm.podcasts) { podcast in
                PodcastRowView(
                    podcast: podcast,
                    onPlay: {
                        if let ep = podcast.episodes
                            .sorted(by: { $0.publishDate > $1.publishDate }).first {
                            playerManager?.play(ep)
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

#Preview {
    SubscriptionsListView()
        .modelContainer(SampleData.container)
}
