import Foundation

extension URL {
    /// Appends a path that may itself carry a query string (e.g. `"/api/x?y=1"`),
    /// splitting path from query correctly.
    ///
    /// `appendingPathComponent` treats the whole argument as one literal path
    /// segment and percent-encodes `?` (turning `?range=24h` into a bogus path
    /// segment `%3Frange=24h` instead of a query string) — this is the
    /// correct replacement for building hub/cloud API requests.
    func appendingCarlPath(_ pathAndQuery: String) -> URL {
        guard let parts = URLComponents(string: pathAndQuery) else {
            return appendingPathComponent(pathAndQuery)
        }
        var result = self
        if !parts.path.isEmpty {
            result = result.appendingPathComponent(parts.path)
        }
        guard let query = parts.percentEncodedQuery else { return result }
        guard var comps = URLComponents(url: result, resolvingAgainstBaseURL: false) else { return result }
        comps.percentEncodedQuery = query
        return comps.url ?? result
    }
}
