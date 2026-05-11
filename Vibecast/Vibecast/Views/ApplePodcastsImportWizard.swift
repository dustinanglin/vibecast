import SwiftUI
import UIKit

/// The three-step Apple Podcasts import wizard, presented as a sub-sheet
/// from `AddPodcastSheet`'s "Import from Apple Podcasts" row.
///
/// State sources:
/// - `@AppStorage` flag `hasOpenedApplePodcastsImportShortcutInstall` — Step 1 ✓
/// - `ApplePodcastsImportSession.shared.pendingFeedURLs + isFresh` — Step 2 ✓
/// - `SubscriptionManager.isImportingFeeds + lastImportSummary` — Step 3 progress/summary
struct ApplePodcastsImportWizard: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.subscriptionManager) private var manager
    @Bindable private var session = ApplePodcastsImportSession.shared

    @AppStorage("hasOpenedApplePodcastsImportShortcutInstall")
    private var hasOpenedInstall: Bool = false

    /// True once an import has completed in this wizard session — drives the
    /// summary row vs. the import-button row.
    @State private var didImport: Bool = false

    /// Replace this with the real iCloud share URL produced at the end of
    /// Task 1. Until then, the install button does nothing useful — but the
    /// rest of the wizard is fully testable in the simulator with a
    /// hand-constructed `vibecast://import-feeds?urls=…` URL pasted via the
    /// simulator's URL-open menu (Device → Open URL).
    private static let iCloudShortcutInstallURL =
        URL(string: "https://www.icloud.com/shortcuts/PLACEHOLDER")!

    private static let runShortcutURL =
        URL(string: "shortcuts://run-shortcut?name=Vibecast%20Import")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    intro
                    stepOne
                    stepTwo
                    stepThree
                }
                .padding(.horizontal, Brand.Layout.rowPadding)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Brand.Color.bg)
            .scrollContentBackground(.hidden)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Import from Apple Podcasts")
                        .font(Brand.Font.serifSubtitle())
                        .foregroundStyle(Brand.Color.ink)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(Brand.Font.uiButton())
                        .foregroundStyle(Brand.Color.ink)
                }
            }
            .toolbarBackground(Brand.Color.bg, for: .navigationBar)
        }
    }

    // MARK: - Sections

    private var intro: some View {
        Text("Bring your Apple Podcasts subscriptions into Vibecast in three steps. The first time you do this, you'll install a small Shortcuts shortcut — after that, just run it to sync.")
            .font(Brand.Font.uiBody())
            .foregroundStyle(Brand.Color.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var stepOne: some View {
        stepRow(
            number: 1,
            isChecked: hasOpenedInstall,
            title: "Install Shortcut",
            description: "Add the Vibecast Import shortcut to your Shortcuts app. This only needs to happen once.",
            buttonTitle: "Install Shortcut",
            buttonEnabled: true,
            action: {
                hasOpenedInstall = true
                UIApplication.shared.open(Self.iCloudShortcutInstallURL)
            }
        )
    }

    private var stepTwo: some View {
        let shortcutsInstalled = UIApplication.shared.canOpenURL(URL(string: "shortcuts://")!)
        return stepRow(
            number: 2,
            isChecked: session.pendingFeedURLs != nil && session.isFresh,
            title: shortcutsInstalled ? "Run Shortcut" : "Install Shortcuts.app",
            description: stepTwoDescription(shortcutsInstalled: shortcutsInstalled),
            buttonTitle: shortcutsInstalled ? "Run Shortcut" : "Get Shortcuts on App Store",
            buttonEnabled: hasOpenedInstall,
            action: {
                if shortcutsInstalled {
                    UIApplication.shared.open(Self.runShortcutURL)
                } else {
                    UIApplication.shared.open(Self.shortcutsAppStoreURL)
                }
            }
        )
    }

    private func stepTwoDescription(shortcutsInstalled: Bool) -> String {
        if !shortcutsInstalled {
            return "The Shortcuts app isn't installed on this device. Install it from the App Store to continue."
        }
        if session.pendingFeedURLs != nil && !session.isFresh {
            return "The last run is too old. Open the shortcut and run it again."
        }
        return "Open the shortcut and run it. It reads your Apple Podcasts subscriptions and sends them here."
    }

    private static let shortcutsAppStoreURL =
        URL(string: "https://apps.apple.com/app/shortcuts/id915249334")!

    @ViewBuilder
    private var stepThree: some View {
        let urls = session.pendingFeedURLs
        let isReady = (urls != nil) && session.isFresh
        let importingFeeds = manager?.isImportingFeeds ?? false
        let summary = manager?.lastImportSummary

        if didImport, let summary {
            stepThreeSummary(summary)
        } else if importingFeeds {
            stepThreeProgress(count: urls?.count ?? 0)
        } else {
            stepRow(
                number: 3,
                isChecked: false,
                title: "Import",
                description: stepThreeDescription(urls: urls),
                buttonTitle: stepThreeButtonTitle(urls: urls),
                buttonEnabled: isReady && (urls?.isEmpty == false),
                action: { Task { await runImport() } }
            )
        }
    }

    private func stepThreeDescription(urls: [URL]?) -> String {
        guard let urls else { return "Run the shortcut to see what's ready to import." }
        if urls.isEmpty {
            return "No subscribable podcasts found in your Apple Podcasts library. Your shows may all be Apple Originals, which don't have public RSS feeds."
        }
        return "Found \(urls.count) podcast\(urls.count == 1 ? "" : "s") ready to import."
    }

    private func stepThreeButtonTitle(urls: [URL]?) -> String {
        guard let urls, !urls.isEmpty else { return "Import" }
        return "Import \(urls.count) Podcast\(urls.count == 1 ? "" : "s")"
    }

    private func stepThreeProgress(count: Int) -> some View {
        stepCard {
            stepHeader(number: 3, isChecked: false, title: "Importing")
            ProgressView()
                .controlSize(.regular)
                .padding(.top, 4)
            Text("Subscribing to \(count) podcast\(count == 1 ? "" : "s")…")
                .font(Brand.Font.uiBody())
                .foregroundStyle(Brand.Color.inkSecondary)
        }
    }

    private func stepThreeSummary(_ summary: ImportSummary) -> some View {
        stepCard {
            stepHeader(number: 3, isChecked: true, title: "Imported")
            Text(summaryMessage(summary))
                .font(Brand.Font.uiBody())
                .foregroundStyle(Brand.Color.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Done") {
                session.clear()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(Brand.Color.ink)
            .padding(.top, 4)
        }
    }

    private func summaryMessage(_ summary: ImportSummary) -> String {
        var pieces: [String] = []
        if summary.succeeded > 0 { pieces.append("Imported \(summary.succeeded)") }
        if summary.alreadySubscribed > 0 { pieces.append("Already subscribed \(summary.alreadySubscribed)") }
        if summary.failed > 0 { pieces.append("Failed \(summary.failed)") }
        if pieces.isEmpty { return "Nothing to import." }
        return pieces.joined(separator: " · ")
    }

    private func runImport() async {
        guard let urls = session.pendingFeedURLs, !urls.isEmpty else { return }
        await manager?.importFeeds(urls)
        didImport = true
    }

    // MARK: - Step row primitives

    private func stepRow(
        number: Int,
        isChecked: Bool,
        title: String,
        description: String,
        buttonTitle: String,
        buttonEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        stepCard {
            stepHeader(number: number, isChecked: isChecked, title: title)
            Text(description)
                .font(Brand.Font.uiBody())
                .foregroundStyle(Brand.Color.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: action) {
                Text(buttonTitle)
                    .font(Brand.Font.uiButton())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(buttonEnabled ? Brand.Color.ink : Brand.Color.inkHairline)
                    .foregroundStyle(Brand.Color.paper)
                    .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.inline))
            }
            .buttonStyle(.plain)
            .disabled(!buttonEnabled)
            .padding(.top, 4)
        }
    }

    private func stepHeader(number: Int, isChecked: Bool, title: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .strokeBorder(Brand.Color.inkHairline, lineWidth: Brand.Layout.hairlineWidth)
                    .background(Circle().fill(isChecked ? Brand.Color.accent : Brand.Color.paper))
                    .frame(width: 28, height: 28)
                if isChecked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Brand.Color.paper)
                } else {
                    Text("\(number)")
                        .font(Brand.Font.monoEyebrow())
                        .foregroundStyle(Brand.Color.inkSecondary)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("STEP \(number)")
                    .font(Brand.Font.monoEyebrow())
                    .tracking(Brand.Layout.monoTracking)
                    .foregroundStyle(Brand.Color.inkMuted)
                Text(title)
                    .font(Brand.Font.serifSubtitle())
                    .foregroundStyle(Brand.Color.ink)
            }
            Spacer()
        }
    }

    private func stepCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(16)
        .background(Brand.Color.paper)
        .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Brand.Radius.card)
                .strokeBorder(Brand.Color.inkHairline, lineWidth: Brand.Layout.hairlineWidth)
        )
    }
}
