import Foundation

/// Stubs out network responses for tests. Register canned (Data, HTTPURLResponse) pairs by URL.
final class MockURLProtocol: URLProtocol {
    typealias Stub = (data: Data, response: HTTPURLResponse)
    nonisolated(unsafe) static var stubs: [URL: Stub] = [:]
    nonisolated(unsafe) static var error: Error?

    static func register(url: URL, data: Data, statusCode: Int = 200) {
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: nil)!
        stubs[url] = (data, response)
    }

    static func reset() {
        stubs.removeAll()
        error = nil
    }

    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let error = MockURLProtocol.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        guard let url = request.url, let stub = MockURLProtocol.stubs[url] else {
            client?.urlProtocol(self, didFailWithError: URLError(.fileDoesNotExist))
            return
        }
        client?.urlProtocol(self, didReceive: stub.response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
