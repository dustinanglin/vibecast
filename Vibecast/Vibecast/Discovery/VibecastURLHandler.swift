import Foundation

/// Static namespace for parsing `vibecast://` URL-scheme payloads.
///
/// Current actions:
/// - `vibecast://import-feeds?urls=<urlencoded-newline-separated-list>`
///   — receives a list of RSS feed URLs from the "Vibecast Import" Shortcuts
///   shortcut and writes them into `ApplePodcastsImportSession`.
///
/// Unknown hosts return `false` from `handle` so the caller (typically the
/// app root's `.onOpenURL`) knows to ignore the URL rather than swallowing it.
enum VibecastURLHandler {
    /// Top-level entry point. Dispatches a `vibecast://...` URL to the right
    /// receiver. Returns `true` if the URL was recognized and handled,
    /// `false` otherwise.
    @MainActor
    @discardableResult
    static func handle(_ url: URL, session: ApplePodcastsImportSession) -> Bool {
        guard url.scheme == "vibecast" else { return false }
        switch url.host {
        case "import-feeds":
            let urls = parseImportFeedsURL(url)
            session.receive(urls)
            return true
        default:
            return false
        }
    }

    /// Parses a `vibecast://import-feeds?urls=<encoded-list>` URL into a
    /// validated, deduplicated list of feed URLs. Returns `[]` if the URL
    /// has no `urls` parameter or if it's empty — empty is distinct from
    /// nil at the session layer (see `handle`'s comment).
    static func parseImportFeedsURL(_ url: URL) -> [URL] {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return []
        }
        let raw = components.queryItems?.first(where: { $0.name == "urls" })?.value ?? ""

        var seen = Set<String>()
        var result: [URL] = []
        for line in raw.split(separator: "\n", omittingEmptySubsequences: true) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty,
                  let parsed = URL(string: trimmed),
                  parsed.scheme == "http" || parsed.scheme == "https"
            else { continue }
            if seen.insert(parsed.absoluteString).inserted {
                result.append(parsed)
            }
        }
        return result
    }
}
