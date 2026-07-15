import Foundation
import CryptoKit

/// Disk layout for downloaded episode audio. Files live in Application
/// Support (NOT Caches — Caches is purgeable under storage pressure and
/// offline listening must survive it), named by SHA256 of the episode's
/// audioURL — same content-addressed scheme as `ArtworkCache`. Paths are
/// always derived, never persisted, so container relocation between app
/// updates can't strand stale absolute paths.
///
/// Stateless — every member is nonisolated so delegate threads can call it
/// synchronously.
enum DownloadStore {

    nonisolated static var directoryURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads", isDirectory: true)
    }

    nonisolated static func fileURL(for audioURL: String) -> URL {
        let digest = SHA256.hash(data: Data(audioURL.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return directoryURL
            .appendingPathComponent(name)
            .appendingPathExtension(preferredExtension(for: audioURL))
    }

    /// The URL's own extension when it's a recognized audio container,
    /// otherwise "mp3". AVPlayer uses the extension as a format hint for
    /// local files, so an accurate one matters more than a pretty one.
    nonisolated private static func preferredExtension(for audioURL: String) -> String {
        guard let url = URL(string: audioURL) else { return "mp3" }
        let ext = url.pathExtension.lowercased()
        let known: Set<String> = ["mp3", "m4a", "m4b", "aac", "wav", "mp4"]
        return known.contains(ext) ? ext : "mp3"
    }

    nonisolated static func exists(for audioURL: String) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: audioURL).path)
    }

    /// Move a completed download's temp file into the store. Must be called
    /// synchronously from `urlSession(_:downloadTask:didFinishDownloadingTo:)`
    /// — the temp file is deleted by the system when that delegate returns.
    @discardableResult
    nonisolated static func store(tempFile: URL, for audioURL: String) throws -> URL {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        var destination = fileURL(for: audioURL)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: tempFile, to: destination)
        // Re-downloadable content is excluded from iCloud/iTunes backup
        // per Apple data-storage guidelines.
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? destination.setResourceValues(values)
        return destination
    }

    nonisolated static func delete(for audioURL: String) {
        try? FileManager.default.removeItem(at: fileURL(for: audioURL))
    }

    nonisolated static func deleteAll() {
        try? FileManager.default.removeItem(at: directoryURL)
    }

    nonisolated static func totalBytes() -> Int64 {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directoryURL, includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }
        return files.reduce(Int64(0)) { sum, url in
            sum + Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
    }
}
