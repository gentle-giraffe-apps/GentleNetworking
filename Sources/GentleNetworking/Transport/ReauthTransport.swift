//  Jonathan Ritchey
import Foundation

public struct ReauthTransport: HTTPTransportProtocol {
    let inner: HTTPTransportProtocol
    let authService: AuthServiceProtocol
    let refreshToken: @Sendable () async throws -> Void
    private let coordinator = RefreshCoordinator()

    public init(
        inner: HTTPTransportProtocol = RetryTransport(),
        authService: AuthServiceProtocol = SystemKeyChainAuthService(),
        refreshToken: @escaping @Sendable () async throws -> Void
    ) {
        self.inner = inner
        self.authService = authService
        self.refreshToken = refreshToken
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await inner.data(for: request)
        guard response.statusCode == 401 else { return (data, response) }
        try await coordinator.refresh(using: refreshToken)
        let reauthorized = try await authService.authorize(request)
        return try await inner.data(for: reauthorized)
    }
}

private actor RefreshCoordinator {
    private var activeRefresh: Task<Void, any Error>?

    func refresh(using refreshToken: @escaping @Sendable () async throws -> Void) async throws {
        if let active = activeRefresh {
            try await active.value
            return
        }
        let task = Task { try await refreshToken() }
        activeRefresh = task
        defer { activeRefresh = nil }
        try await task.value
    }
}
