import SwiftUI

struct AddPodcastSheet: View {
    let manager: SubscriptionManager

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [PodcastSearchResult] = []
    @State private var phase: Phase = .idle
    @State private var lastSubmittedQuery = ""

    enum Phase { case idle, searching, results, empty, error }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Add Podcast")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
                .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search podcasts")
                .task(id: query) {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    if Task.isCancelled { return }
                    await runSearch()
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle:
            ContentUnavailableView(
                "Search the iTunes podcast directory",
                systemImage: "magnifyingglass",
                description: Text("Search by title, author, or topic.")
            )
        case .searching:
            ProgressView().controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            ContentUnavailableView.search(text: lastSubmittedQuery)
        case .error:
            ContentUnavailableView(
                "Couldn't reach iTunes",
                systemImage: "wifi.exclamationmark",
                description: Text("Check your connection and try again.")
            )
        case .results:
            List(results) { result in
                SearchResultRow(
                    result: result,
                    isSubscribed: manager.isSubscribed(feedURL: result.feedURL),
                    isInFlight: manager.inFlightSubscriptions.contains(result.feedURL),
                    isFailed: manager.failedSubscribes.contains(result.feedURL),
                    onTapSubscribe: {
                        Task { await manager.subscribe(to: result) }
                    }
                )
                .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14))
            }
            .listStyle(.plain)
        }
    }

    private func runSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            phase = .idle
            results = []
            return
        }

        phase = .searching
        lastSubmittedQuery = trimmed
        do {
            let fetched = try await manager.search(trimmed)
            results = fetched
            phase = fetched.isEmpty ? .empty : .results
        } catch {
            phase = .error
        }
    }
}
