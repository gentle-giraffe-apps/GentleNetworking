//  Jonathan Ritchey
import Foundation

public enum JitterStrategy: Sendable {
    /// Full jitter: random(0 ... exponentialDelay). Spreads retries across the
    /// entire window, minimising collision probability in thundering-herd scenarios.
    case full
    /// Equal jitter: exponentialDelay/2 + random(0 ... exponentialDelay/2).
    /// Guarantees a minimum wait of half the exponential delay while still
    /// decorrelating concurrent retriers.
    case equal
    /// Decorrelated jitter: random(baseDelay ... previousDelay * 3).
    /// Each successive delay depends on the last, producing a wider spread
    /// that naturally adapts to sustained contention.
    case decorrelated
}

public struct RetryPolicy: Sendable {
    public let maxRetries: Int
    public let baseDelay: TimeInterval
    public let maxDelay: TimeInterval
    public let jitter: JitterStrategy?
    public let shouldRetry: @Sendable (Int, any Error) -> Bool

    public init(
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 0.5,
        maxDelay: TimeInterval = 30.0,
        jitter: JitterStrategy? = .full,
        shouldRetry: @escaping @Sendable (Int, any Error) -> Bool = RetryPolicy.defaultShouldRetry
    ) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.jitter = jitter
        self.shouldRetry = shouldRetry
    }

    public static func defaultShouldRetry(statusCode: Int, error: any Error) -> Bool {
        if let networkError = error as? NetworkError,
           case .httpStatusError(let statusError) = networkError {
            switch statusError {
            case .rateLimited, .internalServerError, .serviceUnavailable:
                return true
            case .serverError:
                return true
            default:
                return false
            }
        }
        if error is NetworkError { return false }
        return true
    }

    func delay(forAttempt attempt: Int, previousDelay: TimeInterval) -> TimeInterval {
        let exponential = baseDelay * pow(2.0, Double(attempt))
        let capped = min(exponential, maxDelay)

        guard let jitter else { return capped }

        switch jitter {
        case .full:
            return Double.random(in: 0...capped)
        case .equal:
            let half = capped / 2.0
            return half + Double.random(in: 0...half)
        case .decorrelated:
            let upper = min(maxDelay, previousDelay * 3.0)
            return Double.random(in: baseDelay...max(baseDelay, upper))
        }
    }
}

public struct RetryTransport: HTTPTransportProtocol {
    let inner: HTTPTransportProtocol
    let policy: RetryPolicy

    public init(
        inner: HTTPTransportProtocol = URLSessionTransport(session: .shared),
        policy: RetryPolicy = RetryPolicy()
    ) {
        self.inner = inner
        self.policy = policy
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var lastError: (any Error)?
        var previousDelay = policy.baseDelay

        for attempt in 0...policy.maxRetries {
            do {
                let (data, response) = try await inner.data(for: request)

                if (200..<300).contains(response.statusCode) {
                    return (data, response)
                }

                let statusError = HTTPStatusError(statusCode: response.statusCode)!
                let wrappedError = NetworkError.httpStatusError(statusError)

                guard attempt < policy.maxRetries,
                      policy.shouldRetry(response.statusCode, wrappedError) else {
                    return (data, response)
                }

                lastError = wrappedError
            } catch {
                guard attempt < policy.maxRetries,
                      policy.shouldRetry(0, error) else {
                    throw error
                }
                lastError = error
            }

            let delay = policy.delay(forAttempt: attempt, previousDelay: previousDelay)
            previousDelay = delay
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        throw lastError!
    }
}
