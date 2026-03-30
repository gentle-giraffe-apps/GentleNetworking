//  Jonathan Ritchey
import Foundation
import Security

public enum ServerTrustError: Swift.Error, Sendable {
    case trustEvaluationFailed
    case noCertificateFound
    case noPublicKeyFound
    case certificatePinningFailed(host: String)
}

public protocol ServerTrustEvaluator: Sendable {
    func evaluate(_ trust: SecTrust, forHost host: String) throws
}
