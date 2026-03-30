//  Jonathan Ritchey
import Foundation
import Security

public struct CertificatePinningEvaluator: ServerTrustEvaluator {

    public let pinnedCertificates: Set<Data>

    public init(pinnedCertificates: Set<Data>) {
        self.pinnedCertificates = pinnedCertificates
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
            let certificateData = SecCertificateCopyData(certificate) as Data
            if pinnedCertificates.contains(certificateData) {
                return
            }
        }

        throw ServerTrustError.certificatePinningFailed(host: host)
    }
}
