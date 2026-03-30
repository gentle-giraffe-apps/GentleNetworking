//  Jonathan Ritchey
import Foundation
import Security

public struct PinningTransport: HTTPTransportProtocol {

    private let session: URLSession
    private let delegate: PinningDelegate

    public init(
        pinnedDomains: [String: any ServerTrustEvaluator],
        configuration: URLSessionConfiguration = .default
    ) {
        let delegate = PinningDelegate(pinnedDomains: pinnedDomains)
        self.delegate = delegate
        self.session = URLSession(
            configuration: configuration,
            delegate: delegate,
            delegateQueue: nil
        )
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponseType
        }
        return (data, httpResponse)
    }
}

private final class PinningDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    let pinnedDomains: [String: any ServerTrustEvaluator]

    init(pinnedDomains: [String: any ServerTrustEvaluator]) {
        self.pinnedDomains = pinnedDomains
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            return (.performDefaultHandling, nil)
        }

        let host = challenge.protectionSpace.host

        guard let evaluator = pinnedDomains[host] else {
            return (.performDefaultHandling, nil)
        }

        do {
            try evaluator.evaluate(trust, forHost: host)
            return (.useCredential, URLCredential(trust: trust))
        } catch {
            return (.cancelAuthenticationChallenge, nil)
        }
    }
}
