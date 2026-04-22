import SwiftData
import Foundation

@MainActor
struct SampleData {
    static let container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let c = try! ModelContainer(for: Podcast.self, Episode.self, configurations: config)
        insertSampleData(into: ModelContext(c))
        return c
    }()

    static func insertSampleData(into context: ModelContext) {
        let specs: [(String, String)] = [
            ("Hard Fork", "The New York Times"),
            ("Acquired", "Ben Gilbert and David Rosenthal"),
            ("The Vergecast", "The Verge"),
            ("Darknet Diaries", "Jack Rhysider"),
            ("Planet Money", "NPR"),
        ]

        for (position, (podcastTitle, author)) in specs.enumerated() {
            let podcast = Podcast(
                title: podcastTitle,
                author: author,
                artworkURL: nil,
                feedURL: "https://feeds.example.com/\(podcastTitle.lowercased().replacingOccurrences(of: " ", with: "-"))",
                sortPosition: position
            )
            context.insert(podcast)

            for i in 0..<12 {
                let daysAgo = Double(i) * 7
                let duration = [3600, 4500, 2700, 5400, 3900, 6600][i % 6]
                let audioURL = (position == 0 && i == 0) ? testAudioURL : ""
                let ep = Episode(
                    podcast: podcast,
                    title: sampleTitle(index: i),
                    publishDate: Date().addingTimeInterval(-daysAgo * 86400),
                    descriptionText: sampleDescription(index: i),
                    durationSeconds: (position == 0 && i == 0) ? 15 : duration,
                    audioURL: audioURL
                )
                switch i {
                case 0 where position == 1:
                    ep.listenedStatus = .inProgress
                    ep.playbackPosition = Double(duration) * 0.35
                case 0 where position == 2:
                    ep.listenedStatus = .played
                    ep.playbackPosition = Double(duration)
                case 1, 2, 3:
                    ep.listenedStatus = .played
                    ep.playbackPosition = Double(duration)
                default:
                    break
                }
                context.insert(ep)
                podcast.episodes.append(ep)
            }
        }

        try? context.save()
    }

    /// Publicly hosted short MP3 used to verify audio playback in the simulator.
    /// Replace with any reachable audio URL if this stops resolving.
    static let testAudioURL = "https://download.samplelib.com/mp3/sample-15s.mp3"

    private static let seededDefaultsKey = "didSeedSampleData"

    /// Call once at app launch. Seeds sample data only if the UserDefaults flag
    /// is unset, so user-deleted or reordered podcasts survive relaunches.
    static func seedIfNeeded(into context: ModelContext) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: seededDefaultsKey) else { return }
        insertSampleData(into: context)
        defaults.set(true, forKey: seededDefaultsKey)
    }

    private static func sampleTitle(index: Int) -> String {
        let titles = [
            "The Future of AI Regulation in Europe",
            "How Figma Became the Design Standard",
            "Inside the Semiconductor Supply Chain",
            "The Long Road to Autonomous Vehicles and What It Means for Cities",
            "Why the Dollar Is Still King",
            "The Social Media Paradox",
            "Rethinking the Office",
            "Climate Tech's Quiet Revolution",
            "The Streaming Wars Are Not Over",
            "What Happened to Crypto",
            "The Rise of the Creator Economy",
            "Big Tech Under Pressure",
        ]
        return titles[index % titles.count]
    }

    private static func sampleDescription(index: Int) -> String {
        let descs = [
            "New rules could reshape how companies deploy large language models across the EU.",
            "A deep dive into collaborative design tools and why they won.",
            "From Taiwan to Texas: the geopolitics of chip manufacturing.",
            "Self-driving cars keep failing. Here is why the timeline keeps slipping.",
            "The global reserve currency and its uncertain future in a multipolar world.",
            "Platforms that promised connection are delivering anxiety instead.",
        ]
        return descs[index % descs.count]
    }
}
