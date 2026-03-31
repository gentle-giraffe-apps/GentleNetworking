//  Jonathan Ritchey
import Foundation

public protocol ETagStoreProtocol: Sendable {
    func cachedResponse(for key: String) async -> ETagCacheEntry?
    func store(_ entry: ETagCacheEntry, for key: String) async
    func remove(for key: String) async
    func removeAll() async
}

public struct ETagCacheEntry: Sendable {
    public let etag: String
    public let data: Data
    public let response: HTTPURLResponse

    public init(etag: String, data: Data, response: HTTPURLResponse) {
        self.etag = etag
        self.data = data
        self.response = response
    }
}

public actor InMemoryETagStore: ETagStoreProtocol {
    private var cache: [String: ETagCacheEntry] = [:]
    private var accessOrder: [String] = []
    private let maxEntries: Int

    public init(maxEntries: Int = 100) {
        self.maxEntries = maxEntries
    }

    public func cachedResponse(for key: String) -> ETagCacheEntry? {
        guard let entry = cache[key] else { return nil }
        touchKey(key)
        return entry
    }

    public func store(_ entry: ETagCacheEntry, for key: String) {
        cache[key] = entry
        touchKey(key)
        evictIfNeeded()
    }

    public func remove(for key: String) {
        cache[key] = nil
        accessOrder.removeAll { $0 == key }
    }

    public func removeAll() {
        cache.removeAll()
        accessOrder.removeAll()
    }

    private func touchKey(_ key: String) {
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
    }

    private func evictIfNeeded() {
        while cache.count > maxEntries, let oldest = accessOrder.first {
            cache[oldest] = nil
            accessOrder.removeFirst()
        }
    }
}
