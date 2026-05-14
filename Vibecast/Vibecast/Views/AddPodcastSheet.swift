import SwiftUI
import UniformTypeIdentifiers

struct AddPodcastSheet: View {
    @Environment(\.subscriptionManager) private var manager

    var body: some View {
        if let manager {
            LoadedSheet(manager: manager)
        } else {
            #if DEBUG
            let _ = { assertionFailure("subscriptionManager was not injected into AddPodcastSheet") }()
            #endif
            ContentUnavailableView(
                "Manager unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text("Subscription manager wasn't injected. This is a bug.")
            )
            .font(Brand.Font.serifSubtitle())
        }
    }
}

// MARK: - Private implementation

private enum Phase { case idle, searching, results, empty, error }

private struct LoadedSheet: View {
    let manager: SubscriptionManager

    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [PodcastSearchResult] = []
    @State private var phase: Phase = .idle
    @State private var lastSubmittedQuery = ""

    @State private var showFileImporter = false
    @State private var showImportSummaryAlert = false
    @State private var showImportFailureAlert = false
    @State private var showApplePodcastsWizard: Bool = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Brand.Color.bg
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Custom drag handle
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Brand.Color.inkHairline)
                        .frame(width: 36, height: 4)
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                    content
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Brand.Color.bg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(Brand.Font.uiButton())
                        .foregroundStyle(Brand.Color.ink)
                }
                ToolbarItem(placement: .principal) {
                    Text("Add Podcast")
                        .font(Brand.Font.serifSubtitle())
                        .foregroundStyle(Brand.Color.ink)
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search podcasts")
            .safeAreaInset(edge: .top) {
                VStack(spacing: 8) {
                    applePodcastsImportButton
                    importButton
                }
                .padding(.horizontal, Brand.Layout.rowPadding)
                .padding(.bottom, 8)
                .background(Brand.Color.bg)
            }
            .sheet(isPresented: $showApplePodcastsWizard) {
                ApplePodcastsImportWizard()
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
            .presentationDragIndicator(.hidden)
            .onAppear {
                // Cold path: sheet just became visible because either the
                // user tapped Add Podcast, or SubscriptionsListView popped
                // us in response to a fresh shortcut payload. Consume the
                // flag and auto-pop the wizard if a payload is waiting.
                if ApplePodcastsImportSession.shared.shouldPresentWizard {
                    showApplePodcastsWizard = true
                    ApplePodcastsImportSession.shared.shouldPresentWizard = false
                }
            }
            .onChange(of: ApplePodcastsImportSession.shared.shouldPresentWizard) { _, newValue in
                // Warm path: sheet is already visible (user may be mid-
                // wizard, or dismissed it but kept AddPodcastSheet open)
                // when a new shortcut run arrives. .onAppear doesn't re-
                // fire while the sheet stays mounted, so handle the
                // present + flag-reset here too. Idempotent if the wizard
                // is already on screen.
                guard newValue else { return }
                showApplePodcastsWizard = true
                ApplePodcastsImportSession.shared.shouldPresentWizard = false
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if manager.isImportingOPML {
            VStack(spacing: 12) {
                ProgressView().controlSize(.large)
                Text("Importing podcasts…")
                    .font(Brand.Font.uiBody())
                    .foregroundStyle(Brand.Color.inkSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Brand.Color.bg)
        } else {
            switch phase {
            case .idle:
                ContentUnavailableView(
                    "Search the iTunes podcast directory",
                    systemImage: "magnifyingglass",
                    description: Text("Search by title, author, or topic.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Brand.Color.bg)
            case .searching:
                ProgressView().controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Brand.Color.bg)
            case .empty:
                ContentUnavailableView.search(text: lastSubmittedQuery)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Brand.Color.bg)
            case .error:
                ContentUnavailableView(
                    "Couldn't reach iTunes",
                    systemImage: "wifi.exclamationmark",
                    description: Text("Check your connection and try again.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Brand.Color.bg)
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
                    .listRowBackground(Brand.Color.bg)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Brand.Color.bg)
            }
        }
    }

    private var applePodcastsImportButton: some View {
        Button {
            showApplePodcastsWizard = true
        } label: {
            Label("Import Podcasts from this Phone", systemImage: "iphone.gen3")
                .font(Brand.Font.uiButton())
                .foregroundStyle(Brand.Color.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Brand.Color.paper)
                .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.inline))
                .overlay(
                    RoundedRectangle(cornerRadius: Brand.Radius.inline)
                        .strokeBorder(Brand.Color.inkHairline, lineWidth: Brand.Layout.hairlineWidth)
                )
        }
        .buttonStyle(.plain)
    }

    private var importButton: some View {
        Button {
            showFileImporter = true
        } label: {
            Label("Import from File", systemImage: "square.and.arrow.down")
                .font(Brand.Font.uiButton())
                .foregroundStyle(Brand.Color.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Brand.Color.paper)
                .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.inline))
                .overlay(
                    RoundedRectangle(cornerRadius: Brand.Radius.inline)
                        .strokeBorder(Brand.Color.inkHairline, lineWidth: Brand.Layout.hairlineWidth)
                )
        }
        .buttonStyle(.plain)
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
