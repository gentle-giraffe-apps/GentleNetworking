# Conventions

## Swift Version & Concurrency

- **Swift 6** language mode (`swiftLanguageModes: [.v6]`)
- **Strict concurrency** enforced via compiler flags:
  - `-strict-concurrency=complete`
  - `-warn-concurrency`
  - `-enable-actor-data-race-checks` (debug builds)
- Every public type and protocol conforms to `Sendable`
- All I/O methods are `async throws`

## Value Types

- **Structs over classes** — the only class is `SystemKeyChainStore` (required by keychain API lifecycle)
- Use `actor` when mutable state needs isolation (e.g., `MockKeyChainStore`)

## Naming

- **Protocols** use the `*Protocol` suffix: `NetworkServiceProtocol`, `HTTPTransportProtocol`, `EndpointProtocol`, `APIEnvironmentProtocol`, `AuthServiceProtocol`, `KeyChainStoreProtocol`
- **Exception**: `TokenInvalidationHandler` — callback-style protocol, not an abstraction boundary
- **Mock types** prefixed with `Mock`: `MockNetworkService`, `MockKeyChainStore`

## Enums

- **Never use `none` as a case** — use `Optional` or associated values instead
- Use **associated values** to carry context (e.g., `invalidStatusCode(Int?)`, `ambiguousMatch(count: Int)`, `unexpectedStatus(OSStatus)`)
- Raw-value enums for fixed string mappings (e.g., `HTTPMethod: String`)

## Access Control

- **Explicit `public`** on all API surface: protocols, types, initializers, methods, properties
- Internal/private for implementation details
- `let` properties on structs (immutable by default)

## Error Pattern

Nest error enums inside the owning type:

```swift
public struct CannedResponseTransport: HTTPTransportProtocol {
    public enum Error: Swift.Error, Sendable {
        case missingRequestURL
    }
}
```

All error enums conform to both `Swift.Error` and `Sendable`.

## Dependencies

- **Zero external dependencies** — only `Foundation` and `Security`
- Dependency injection via constructor with sensible defaults:

```swift
public init(
    transport: HTTPTransportProtocol = URLSessionTransport(session: .shared),
    authService: AuthServiceProtocol = SystemKeyChainAuthService(),
    invalidationHandler: TokenInvalidationHandler? = nil,
    jsonDecoder: JSONDecoder? = nil,
    jsonEncoder: JSONEncoder? = nil
)
```

## Testing Framework

- **Swift Testing** (`@Suite`, `@Test`, `#expect`) — not XCTest
- See `Docs/TESTING.md` for details

## Commit Format

```
type: scope: description
```

All lowercase. Examples:
- `doc: readme.md: update badges`
- `ci: speed up CI by reusing compiled artifacts between lanes`

## Code Style

- **No SwiftLint or SwiftFormat** — compiler flags enforce correctness
- **MARK comments** for section organization:
  ```swift
  // MARK: - KeyChainStoreProtocol
  ```
- **Debug logging** uses emoji-prefixed prints:
  ```swift
  print("➡️ \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "")")
  print("🔍 Response Text:\n\(text)")
  ```

## Platform

- **iOS 17+** minimum deployment target
- Package manifest: `swift-tools-version: 6.1`
