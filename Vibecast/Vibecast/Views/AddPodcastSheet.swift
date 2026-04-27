import SwiftUI
import UniformTypeIdentifiers

struct AddPodcastSheet: View {
    let manager: SubscriptionManager

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [PodcastSearchResult] = []
    @State private var phase: Phase = .idle
    @State private var lastSubmittedQuery = ""

    @State private var showFileImporter = false
    @State private var showImportSummaryAlert = false
    @State private var showImportFailureAlert = false

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
                .safeAreaInset(edge: .top) {
                    importButton
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
                .task(id: query) {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    if Task.isCancelled { return }
                    await runSearch()
                }
                .fileImporter(
                    isPresented: $showFileImporter,
                    allowedContentTypes: [
                        UTType(filenameExtension: "opml") ?? .xml,
                        .xml,
                    ],
                    allowsMultipleSelection: false
                ) { result in
                    handleFileImport(result)
                }
                .alert("Import Result", isPresented: $showImportSummaryAlert, presenting: manager.lastImportSummary) { _ in
                    Button("OK") { dismiss() }
                } message: { summary in
                    Text(importSummaryMessage(summary))
                }
                .alert("Couldn't Import", isPresented: $showImportFailureAlert) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Couldn't parse OPML file. Make sure it's a valid OPML export.")
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if manager.isImportingOPML {
            VStack(spacing: 12) {
                ProgressView().controlSize(.large)
                Text("Importing podcasts…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
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
    }

    private var importButton: some View {
        Button {
            showFileImporter = true
        } label: {
            Label("Import from File", systemImage: "square.and.arrow.down")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(manager.isImportingOPML)
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case let .success(urls) = result, let url = urls.first else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        Task {
            defer { url.stopAccessingSecurityScopedResource() }
            guard let data = try? Data(contentsOf: url) else {
                showImportFailureAlert = true
                return
            }
            do {
                try await manager.importOPML(from: data)
                showImportSummaryAlert = true
            } catch {
                showImportFailureAlert = true
            }
        }
    }

    private func importSummaryMessage(_ summary: ImportSummary) -> String {
        var parts: [String] = []
        parts.append("Imported \(summary.succeeded) of \(summary.attempted) podcasts.")
        if summary.alreadySubscribed > 0 {
            parts.append("\(summary.alreadySubscribed) already subscribed.")
        }
        if summary.failed > 0 {
            parts.append("\(summary.failed) couldn't be reached.")
        }
        return parts.joined(separator: " ")
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
