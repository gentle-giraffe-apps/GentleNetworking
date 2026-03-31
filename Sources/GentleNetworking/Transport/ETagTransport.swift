//  Jonathan Ritchey
import Foundation

public struct ETagTransport: HTTPTransportProtocol {
    let inner: HTTPTransportProtocol
    let store: ETagStoreProtocol

    public init(
        inner: HTTPTransportProtocol = URLSessionTransport(session: .shared),
        store: ETagStoreProtocol = InMemoryETagStore()
    ) {
        self.inner = inner
        self.store = store
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard request.httpMethod == nil || request.httpMethod == "GET" else {
            return try await inner.data(for: request)
        }

        let cacheKey = cacheKey(for: request)
        var request = request

        if let cached = await store.cachedResponse(for: cacheKey) {
            request.setValue(cached.etag, forHTTPHeaderField: "If-None-Match")
        }

        let (data, response) = try await inner.data(for: request)

        if response.statusCode == 304, let cached = await store.cachedResponse(for: cacheKey) {
            return (cached.data, cached.response)
        }

        if (200..<300).contains(response.statusCode),
           let etag = response.value(forHTTPHeaderField: "Etag") {
            let entry = ETagCacheEntry(etag: etag, data: data, response: response)
            await store.store(entry, for: cacheKey)
        }

        return (data, response)
    }

    private func cacheKey(for request: URLRequest) -> String {
        request.url?.absoluteString ?? ""
    }
}
