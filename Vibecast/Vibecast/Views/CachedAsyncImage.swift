import SwiftUI
import UIKit
import CryptoKit
import os

/// Drop-in replacement for `AsyncImage` that persists decoded images across
/// view recycling. Two-tier cache: an in-memory `NSCache` for hot decoded
/// `UIImage`s (auto-evicts on memory pressure) and a disk store under
/// `Caches/ArtworkCache/<sha256-of-url>` for cross-launch persistence.
///
/// Why a custom view: SwiftUI's `AsyncImage` does not retain the decoded
/// image across view re-instantiations. As rows recycle during scrolling,
/// each cell sees `phase = .empty` and re-decodes its artwork on the main
/// thread, causing the visible "pop-in" and frame hitches.
///
/// First scroll-through misses both caches and shows the placeholder; once
/// loaded, the same URL renders synchronously from the in-memory cache on
/// every subsequent appearance — no pop-in, no main-thread decode.
struct CachedAsyncImage<Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var loadTask: Task<Void, Never>?

    init(url: URL?, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.placeholder = placeholder
        // Seed @State with a synchronous memory-cache lookup. If the image is
        // already hot, the very first body evaluation renders it — no
        // placeholder flash on cell recycle.
        if let url {
            _image = State(initialValue: ArtworkCache.shared.memoryImage(for: url))
        }
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder()
            }
        }
        .onAppear { startLoadIfNeeded() }
        .onDisappear {
            loadTask?.cancel()
            loadTask = nil
        }
        .onChange(of: url) { _, _ in
            // URL swap: drop the prior image and re-seed from memory cache
            // before kicking off any async work.
            loadTask?.cancel()
            loadTask = nil
            image = url.flatMap { ArtworkCache.shared.memoryImage(for: $0) }
            startLoadIfNeeded()
        }
    }

    private func startLoadIfNeeded() {
        guard image == nil, let url, loadTask == nil else { return }
        loadTask = Task { [url] in
            let loaded = await ArtworkCache.shared.load(url: url)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.image = loaded
                self.loadTask = nil
            }
        }
    }
}

/// Process-wide artwork cache. Memory tier is a bounded `NSCache`; disk tier
/// is the raw downloaded bytes (we store data, not the decoded image, so
/// disk size stays small and we can re-decode at any size).
///
/// `@unchecked Sendable`: `NSCache` and `FileManager` are thread-safe, and
/// the in-flight task map is read/written only from the main actor's
/// `load(url:)` continuation chain.
final class ArtworkCache: @unchecked Sendable {
    static let shared = ArtworkCache()

    private let memory = NSCache<NSString, UIImage>()
    private let diskRoot: URL
    private let session: URLSession

    /// Coalesces concurrent requests for the same URL — if a row scrolls
    /// onscreen while another row with the same URL is mid-load, both
    /// await the single in-flight task instead of double-fetching.
    /// `OSAllocatedUnfairLock` is async-safe (`NSLock`'s `lock`/`unlock`
    /// are not, and trip a Swift 6 hazard warning when used in actor or
    /// detached-task contexts).
    private let inFlight = OSAllocatedUnfairLock<[String: Task<UIImage?, Never>]>(initialState: [:])

    private init() {
        memory.countLimit = 200
        memory.totalCostLimit = 64 * 1024 * 1024 // 64 MB of decoded pixels

        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        diskRoot = caches.appendingPathComponent("ArtworkCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskRoot, withIntermediateDirectories: true)

        // Dedicated session so artwork traffic doesn't share the shared
        // session's connection pool with feed/RSS requests.
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(memoryCapacity: 0, diskCapacity: 0)
        session = URLSession(configuration: config)
    }

    /// Synchronous memory lookup. Returns nil on miss — never touches disk
    /// or network, so it's safe to call during view init.
    func memoryImage(for url: URL) -> UIImage? {
        memory.object(forKey: url.absoluteString as NSString)
    }

    /// Resolve the image for `url`, hitting memory → disk → network in turn.
    /// Concurrent calls for the same URL share a single load task.
    func load(url: URL) async -> UIImage? {
        if let cached = memoryImage(for: url) { return cached }

        let key = url.absoluteString
        let task: Task<UIImage?, Never> = inFlight.withLock { state in
            if let existing = state[key] { return existing }
            let newTask = Task.detached(priority: .userInitiated) { [weak self] in
                await self?.fetch(url: url) ?? nil
            }
            state[key] = newTask
            return newTask
        }

        let image = await task.value
        inFlight.withLock { $0[key] = nil }
        return image
    }

    private func fetch(url: URL) async -> UIImage? {
        let key = url.absoluteString as NSString
        let diskURL = diskPath(for: url)

        // Disk tier: read raw bytes synchronously inside this detached task,
        // decode off the main thread, then publish to the memory tier.
        if let data = try? Data(contentsOf: diskURL),
           let image = UIImage(data: data) {
            memory.setObject(image, forKey: key, cost: data.count)
            return image
        }

        // Network tier: download, write to disk, decode, publish.
        guard let (data, response) = try? await session.data(from: url),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let image = UIImage(data: data)
        else { return nil }

        try? data.write(to: diskURL, options: .atomic)
        memory.setObject(image, forKey: key, cost: data.count)
        return image
    }

    private func diskPath(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return diskRoot.appendingPathComponent(hex)
    }
}
