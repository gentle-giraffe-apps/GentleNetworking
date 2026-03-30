# Security

## Transport Security

GentleNetworking relies on Apple's **App Transport Security (ATS)** and the iOS networking stack for transport-layer protection. All requests made through `URLSessionTransport` (the default transport) inherit:

- **TLS 1.2+** (negotiates TLS 1.3 when the server supports it)
- **Certificate validation** against Apple's trusted CA store
- **Forward secrecy** via ECDHE key exchange
- **128-bit minimum encryption**

These protections are enforced by the OS and enabled by default. No additional configuration is required for production use.

## Certificate Pinning

For most apps, standard ATS validation provides sufficient transport security. Apps with elevated security requirements (banking, healthcare, government) may need SSL certificate pinning to guard against compromised Certificate Authorities or targeted MITM attacks.

GentleNetworking provides a built-in `PinningTransport` with two evaluator strategies, plus escape hatches for fully custom implementations.

### Built-in: PinningTransport

`PinningTransport` is an `HTTPTransportProtocol` implementation that performs SSL pinning via a per-domain `ServerTrustEvaluator`. It creates its own `URLSession` with an internal pinning delegate — no boilerplate required.

#### Public Key Pinning (recommended)

Pin the SHA-256 hash of the server's public key. Survives certificate renewals as long as the same key pair is reused.

```swift
import GentleNetworking
import CryptoKit

// SHA-256 hashes of your server's public keys
let primaryHash: Data = ...   // hash of current key
let backupHash: Data = ...    // hash of a backup key you control

let service = HTTPNetworkService(
    transport: PinningTransport(
        pinnedDomains: [
            "api.example.com": PublicKeyPinningEvaluator(
                pinnedKeyHashes: [primaryHash, backupHash]
            )
        ]
    )
)
```

#### Certificate Pinning

Pin the full DER-encoded certificate bytes. Simpler but breaks on every certificate renewal.

```swift
let certData: Data = ...  // DER-encoded certificate

let service = HTTPNetworkService(
    transport: PinningTransport(
        pinnedDomains: [
            "api.example.com": CertificatePinningEvaluator(
                pinnedCertificates: [certData]
            )
        ]
    )
)
```

#### Custom Evaluator

Implement `ServerTrustEvaluator` for custom validation logic:

```swift
struct MyEvaluator: ServerTrustEvaluator {
    func evaluate(_ trust: SecTrust, forHost host: String) throws {
        // Your custom trust evaluation
    }
}

let service = HTTPNetworkService(
    transport: PinningTransport(
        pinnedDomains: ["api.example.com": MyEvaluator()]
    )
)
```

#### Behavior

- Domains listed in `pinnedDomains` are evaluated by their assigned `ServerTrustEvaluator`. If evaluation fails, the connection is cancelled.
- Domains **not** listed in `pinnedDomains` fall through to iOS default trust evaluation (ATS).
- Both evaluators call `SecTrustEvaluateWithError` first (standard OS validation), then apply their pin check.

### Alternatively: Inject a Custom URLSession

`URLSessionTransport` accepts any `URLSession`, including one with your own pinning delegate:

```swift
let delegate = MyPinningDelegate(...)
let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
let transport = URLSessionTransport(session: session)
let service = HTTPNetworkService(transport: transport)
```

### Alternatively: Write a Custom Transport

For full control, implement `HTTPTransportProtocol` directly:

```swift
struct MyTransport: HTTPTransportProtocol {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        // Your custom implementation with pinning logic
    }
}

let service = HTTPNetworkService(transport: MyTransport())
```

### Pinning Guidance

If you choose to implement pinning, keep these best practices in mind:

- **Pin public keys, not full certificates.** Public key pins survive certificate renewals as long as the same key pair is reused. Certificate pins break on every renewal.
- **Include at least one backup pin.** A second key you control but haven't deployed yet allows rotation without an emergency app update.
- **Pin the leaf or intermediate certificate's key, not the root.** Root keys are too broad to provide meaningful pinning.
- **Consider a report-only mode first.** Log pinning failures before enforcing them to catch false positives in production.
- **Disable pinning in debug builds.** Development proxies and debugging tools (Charles, Proxyman) require standard trust evaluation.
- **Plan for rotation.** Coordinate server certificate changes with app releases, or source pins from remote configuration.

### Apple Info.plist Pinning

iOS 14+ supports declarative certificate pinning via `NSPinnedDomains` in your app's `Info.plist`, under `NSAppTransportSecurity`. This requires no code and is applied at the OS level. See [Apple's Identity Pinning documentation](https://developer.apple.com/news/?id=g9ejcf8y) for details.

## Keychain Storage

`SystemKeyChainAuthService` stores authentication tokens using the system keychain with `kSecAttrAccessibleAfterFirstUnlock` accessibility. Tokens are available after the first device unlock and persist across app launches.

## Reporting Vulnerabilities

If you discover a security vulnerability, please report it privately via [GitHub Security Advisories](https://github.com/gentle-giraffe-apps/GentleNetworking/security/advisories) rather than opening a public issue.
