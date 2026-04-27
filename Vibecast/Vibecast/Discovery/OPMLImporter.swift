import Foundation

@MainActor
protocol OPMLImporter {
    func extractFeedURLs(from data: Data) throws -> [URL]
}

enum OPMLImportError: Error, Equatable {
    case malformed
}

@MainActor
final class StandardOPMLImporter: NSObject, OPMLImporter, XMLParserDelegate {
    private var collected: [URL] = []
    private var seen: Set<String> = []

    func extractFeedURLs(from data: Data) throws -> [URL] {
        collected = []
        seen = []

        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else { throw OPMLImportError.malformed }

        return collected
    }

    // MARK: - XMLParserDelegate

    nonisolated func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard elementName == "outline" else { return }
        guard let xmlUrl = attributeDict["xmlUrl"], !xmlUrl.isEmpty else { return }
        guard let url = URL(string: xmlUrl) else { return }

        // Cross-actor mutation: SAX delegate callbacks fire from the parser's
        // queue. We're @MainActor; the parser is invoked synchronously from
        // extractFeedURLs(from:) which IS on the main actor, so these
        // callbacks fire synchronously on main too. The nonisolated annotation
        // on the delegate methods is only required because XMLParserDelegate's
        // declaration doesn't carry actor isolation.
        MainActor.assumeIsolated {
            let key = url.absoluteString
            guard !seen.contains(key) else { return }
            seen.insert(key)
            collected.append(url)
        }
    }
}
