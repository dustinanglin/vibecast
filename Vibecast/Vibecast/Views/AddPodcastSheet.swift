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
    @Environment(\.duoSheetContext) private var duoSheetContext

    @State private var query = ""
    @State private var results: [PodcastSearchResult] = []
    @State private var phase: Phase = .idle
    @State private var lastSubmittedQuery = ""

    @State private var showFileImporter = false
    /// The file picker hosted in our own sheet, used only where the system
    /// presentation would cover the Stage (part-folded iPhone Duo).
    @State private var showSizedFilePicker = false
    @State private var showImportSummaryAlert = false
    @State private var showImportFailureAlert = false
    @State private var showApplePodcastsWizard: Bool = false

    @State private var showAddByURLAlert = false
    @State private var feedURLText = ""
    @State private var isAddingByURL = false
    @State private var addByURLResult: AddFeedResult?

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
                    HStack(spacing: 8) {
                        addByURLButton
                        importButton
                    }
                }
                .padding(.horizontal, Brand.Layout.rowPadding)
                .padding(.bottom, 8)
                .background(Brand.Color.bg)
            }
            .sheet(isPresented: $showApplePodcastsWizard) {
                ApplePodcastsImportWizard()
                    .duoSheetPlacement()
            }
            .task(id: query) {
                try? await Task.sleep(nanoseconds: 300_000_000)
                if Task.isCancelled { return }
                await runSearch()
            }
            .sheet(isPresented: $showSizedFilePicker) {
                DocumentPickerSheet(contentTypes: Self.importContentTypes) { urls in
                    showSizedFilePicker = false
                    if !urls.isEmpty { handleFileImport(.success(urls)) }
                }
                .ignoresSafeArea()
                .duoSheetPlacement()
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: Self.importContentTypes,
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .alert("Import Result", isPresented: $showImportSummaryAlert, presenting: manager.lastImportSummary) { _ in
                Button("OK") { dismiss() }
            } message: { summary in
                Text(importSummaryMessage(summary))
            }
            .alert("Add from URL", isPresented: $showAddByURLAlert) {
                TextField("https://example.com/feed.xml", text: $feedURLText)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Cancel", role: .cancel) {}
                Button("Add") { addByURL() }
            } message: {
                Text("Paste a podcast's RSS feed address, such as a private or premium feed.")
            }
            .alert(
                addByURLResultTitle,
                isPresented: Binding(
                    get: { addByURLResult != nil },
                    set: { if !$0 { addByURLResult = nil } }
                ),
                presenting: addByURLResult
            ) { result in
                switch result {
                case .added, .alreadySubscribed:
                    Button("OK") { feedURLText = "" }
                case .invalidURL, .failed:
                    Button("Try Again") { showAddByURLAlert = true }
                    Button("Cancel", role: .cancel) { feedURLText = "" }
                }
            } message: { result in
                Text(addByURLResultMessage(result))
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

    private var addByURLButton: some View {
        Button {
            showAddByURLAlert = true
        } label: {
            Group {
                if isAddingByURL {
                    ProgressView()
                } else {
                    Label("Add from URL", systemImage: "link")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .font(Brand.Font.uiButton())
            .foregroundStyle(Brand.Color.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 6)
            .background(Brand.Color.paper)
            .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.inline))
            .overlay(
                RoundedRectangle(cornerRadius: Brand.Radius.inline)
                    .strokeBorder(Brand.Color.inkHairline, lineWidth: Brand.Layout.hairlineWidth)
            )
        }
        .buttonStyle(.plain)
        .disabled(isAddingByURL)
    }

    private func addByURL() {
        let text = feedURLText
        isAddingByURL = true
        Task {
            let result = await manager.addFeed(fromUserText: text)
            isAddingByURL = false
            addByURLResult = result
        }
    }

    private var addByURLResultTitle: String {
        switch addByURLResult {
        case .added: return "Podcast Added"
        case .alreadySubscribed: return "Already Subscribed"
        case .invalidURL: return "Not a Feed Address"
        case .failed, .none: return "Couldn't Add Podcast"
        }
    }

    private func addByURLResultMessage(_ result: AddFeedResult) -> String {
        switch result {
        case .added(let title):
            return "\(title) is now in your library."
        case .alreadySubscribed:
            return "That feed is already in your library."
        case .invalidURL:
            return "That doesn't look like a web address. Check it and try again."
        case .failed:
            return "No podcast feed could be loaded from that address. Check it and try again."
        }
    }

    private static let importContentTypes: [UTType] = [
        UTType(filenameExtension: "opml") ?? .xml,
        .xml,
    ]

    private var importButton: some View {
        Button {
            if duoSheetContext.mode == .stacked {
                showSizedFilePicker = true
            } else {
                showFileImporter = true
            }
        } label: {
            Label("Import from File", systemImage: "square.and.arrow.down")
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .font(Brand.Font.uiButton())
                .foregroundStyle(Brand.Color.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 6)
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
