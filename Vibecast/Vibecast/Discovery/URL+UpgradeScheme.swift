import Foundation

extension URL {
    /// Returns a copy of this URL with the scheme upgraded from `http`
    /// to `https`. Returns self unchanged for `https` URLs or any other
    /// scheme.
    func upgradedToHTTPS() -> URL {
        guard scheme?.lowercased() == "http" else { return self }
        var comps = URLComponents(url: self, resolvingAgainstBaseURL: false)
        comps?.scheme = "https"
        return comps?.url ?? self
    }
}
