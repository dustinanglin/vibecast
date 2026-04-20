import SwiftUI
import SwiftData

struct PodcastDetailView: View {
    let podcast: Podcast
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
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task {
            if viewModel == nil {
                viewModel = PodcastDetailViewModel(podcast: podcast)
            }
        }
    }

    @ViewBuilder
    private func listContent(viewModel vm: PodcastDetailViewModel) -> some View {
        List {
            podcastHeader
                .listRowSeparator(.hidden)

            ForEach(vm.displayedEpisodes) { episode in
                EpisodeRowView(episode: episode, onPlay: { })
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
