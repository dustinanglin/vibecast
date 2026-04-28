import Foundation

enum PodcastSearchError: Error, Equatable {
    case invalidResponse
    case serverError(status: Int)
}

@MainActor
protocol PodcastSearchService {
    func search(_ query: String) async throws -> [PodcastSearchResult]
}

struct PodcastSearchResult: Identifiable, Hashable, Sendable {
    let id: Int                // iTunes collectionId
    let title: String
    let author: String
    let artworkURL: URL?
    let feedURL: URL
}

@MainActor
final class iTunesSearchService: PodcastSearchService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func search(_ query: String) async throws -> [PodcastSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            URLQueryItem(name: "media", value: "podcast"),
            URLQueryItem(name: "term", value: trimmed),
            URLQueryItem(name: "limit", value: "25"),
        ]
        guard let url = components.url else { return [] }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw PodcastSearchError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw PodcastSearchError.serverError(status: http.statusCode)
        }
        let envelope = try JSONDecoder().decode(ITunesSearchEnvelope.self, from: data)
        return envelope.results.compactMap { raw in
            guard let feedURLString = raw.feedUrl,
                  let feedURL = URL(string: feedURLString) else { return nil }
            let artworkURL = (raw.artworkUrl600 ?? raw.artworkUrl100).flatMap(URL.init(string:))
            return PodcastSearchResult(
                id: raw.collectionId,
                title: raw.collectionName ?? "",
                author: raw.artistName ?? "",
                artworkURL: artworkURL,
                feedURL: feedURL
            )
        }
    }

    private struct ITunesSearchEnvelope: Decodable {
        let results: [RawResult]
    }

    private struct RawResult: Decodable {
        let collectionId: Int
        let collectionName: String?
        let artistName: String?
        let artworkUrl600: String?
        let artworkUrl100: String?
        let feedUrl: String?
    }
}
