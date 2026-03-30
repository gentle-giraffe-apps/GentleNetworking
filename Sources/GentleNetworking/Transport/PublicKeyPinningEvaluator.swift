//  Jonathan Ritchey
import Foundation
import Security
import CryptoKit

public struct PublicKeyPinningEvaluator: ServerTrustEvaluator {

    public let pinnedKeyHashes: Set<Data>

    public init(pinnedKeyHashes: Set<Data>) {
        self.pinnedKeyHashes = pinnedKeyHashes
    }

    public func evaluate(_ trust: SecTrust, forHost host: String) throws {
        var error: CFError?
        guard SecTrustEvaluateWithError(trust, &error) else {
            throw ServerTrustError.trustEvaluationFailed
        }

        guard let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
              !chain.isEmpty else {
            throw ServerTrustError.noCertificateFound
        }

        for certificate in chain {
            guard let publicKey = SecCertificateCopyKey(certificate) else { continue }
            guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else { continue }

            let hash = Data(SHA256.hash(data: publicKeyData))
            if pinnedKeyHashes.contains(hash) {
                return
            }
        }

        throw ServerTrustError.certificatePinningFailed(host: host)
    }
}
