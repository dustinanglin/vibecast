import Foundation

@MainActor
protocol OPMLImporter {
    func extractFeedURLs(from data: Data) throws -> [URL]
}

enum OPMLImportError: Error, LocalizedError, Equatable {
    case malformed(line: Int, column: Int)

    var errorDescription: String? {
        switch self {
        case .malformed(let line, let col):
            return "Couldn't parse OPML at line \(line), column \(col). Make sure it's a valid OPML export."
        }
    }
}

@MainActor
final class StandardOPMLImporter: NSObject, OPMLImporter, XMLParserDelegate {
    private var collected: [URL] = []
    private var seen: Set<String> = []

    // Matches a bare '&' not followed by a valid XML entity reference.
    private static let unescapedAmpersand = try! NSRegularExpression(
        pattern: "&(?!(amp|lt|gt|quot|apos|#[0-9]+|#x[0-9a-fA-F]+);)",
        options: []
    )

    private func sanitize(_ data: Data) -> Data {
        guard var s = String(data: data, encoding: .utf8) else { return data }
        let range = NSRange(s.startIndex..., in: s)
        s = Self.unescapedAmpersand.stringByReplacingMatches(
            in: s, range: range, withTemplate: "&amp;"
        )
        return Data(s.utf8)
    }

    func extractFeedURLs(from data: Data) throws -> [URL] {
        collected = []
        seen = []

        let sanitized = sanitize(data)
        let parser = XMLParser(data: sanitized)
        parser.delegate = self
        guard parser.parse() else {
            throw OPMLImportError.malformed(
                line: parser.lineNumber,
                column: parser.columnNumber
            )
        }

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
