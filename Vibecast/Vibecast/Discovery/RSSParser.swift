import Foundation

struct ParsedFeed {
    let podcastTitle: String?
    let podcastAuthor: String?
    let artworkURL: URL?
    let episodes: [ParsedEpisode]
}

struct ParsedEpisode {
    let title: String
    let publishDate: Date
    let descriptionText: String
    let durationSeconds: Int
    let audioURL: String
    let isExplicit: Bool
}

enum RSSParseError: Error {
    case malformed
}

final class RSSParser: NSObject, XMLParserDelegate {
    private static let episodeCap = 50

    private var inItem = false
    private var currentElement = ""
    private var currentText = ""

    private var podcastTitle: String?
    private var podcastAuthor: String?
    private var artworkHref: String?
    private var sawChannelTitle = false

    private struct ItemBuffer {
        var title: String = ""
        var pubDateString: String = ""
        var description: String = ""
        var durationString: String = ""
        var audioURL: String = ""
        var explicit: Bool = false
    }
    private var item = ItemBuffer()
    private var items: [ParsedEpisode] = []

    private static let pubDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return f
    }()

    func parse(_ data: Data) throws -> ParsedFeed {
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = self
        guard xmlParser.parse() else { throw RSSParseError.malformed }

        let sorted = items.sorted { $0.publishDate > $1.publishDate }
        let capped = Array(sorted.prefix(Self.episodeCap))
        return ParsedFeed(
            podcastTitle: podcastTitle,
            podcastAuthor: podcastAuthor,
            artworkURL: artworkHref.flatMap(URL.init(string:)),
            episodes: capped
        )
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        currentText = ""

        if elementName == "item" {
            inItem = true
            item = ItemBuffer()
        } else if elementName == "itunes:image", !inItem {
            artworkHref = attributeDict["href"]
        } else if elementName == "enclosure", inItem {
            item.audioURL = attributeDict["url"] ?? ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let s = String(data: CDATABlock, encoding: .utf8) {
            currentText += s
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        if inItem {
            switch elementName {
            case "title": item.title = text
            case "pubDate": item.pubDateString = text
            case "description", "itunes:summary":
                if item.description.isEmpty { item.description = text }
            case "itunes:duration": item.durationString = text
            case "itunes:explicit":
                item.explicit = (text.lowercased() == "yes" || text.lowercased() == "true")
            case "item":
                inItem = false
                if let parsed = finalizeItem(item) { items.append(parsed) }
            default: break
            }
        } else {
            switch elementName {
            case "title":
                if !sawChannelTitle {
                    podcastTitle = text
                    sawChannelTitle = true
                }
            case "itunes:author":
                podcastAuthor = text
            case "author":
                if podcastAuthor == nil { podcastAuthor = text }
            default: break
            }
        }

        currentText = ""
        currentElement = ""
    }

    private func finalizeItem(_ buf: ItemBuffer) -> ParsedEpisode? {
        let date = Self.pubDateFormatter.date(from: buf.pubDateString) ?? .distantPast
        return ParsedEpisode(
            title: buf.title,
            publishDate: date,
            descriptionText: buf.description,
            durationSeconds: Self.parseDuration(buf.durationString),
            audioURL: buf.audioURL,
            isExplicit: buf.explicit
        )
    }

    static func parseDuration(_ raw: String) -> Int {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }

        let parts = trimmed.split(separator: ":").map(String.init)
        if parts.count == 1 {
            return Int(parts[0]) ?? 0
        }
        let nums = parts.compactMap(Int.init)
        guard nums.count == parts.count else { return 0 }
        switch nums.count {
        case 2: return nums[0] * 60 + nums[1]
        case 3: return nums[0] * 3600 + nums[1] * 60 + nums[2]
        default: return 0
        }
    }
}
