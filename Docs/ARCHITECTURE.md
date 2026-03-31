# Architecture

## Directory Tree

```
GentleNetworking/
├── Package.swift                          # Swift 6.1, iOS 17+, strict concurrency, no external deps
├── Sources/GentleNetworking/
│   ├── Authentication/
│   │   ├── AuthService.swift              # AuthServiceProtocol + default implementations
│   │   ├── SystemKeyChainAuthService.swift # Concrete auth service using system keychain
│   │   └── TokenInvalidationHandler.swift # Callback protocol for 401 handling
│   ├── Decoding/
│   │   └── DateDecodingStrategies.swift   # ISO8601 fractional/non-fractional date strategies
│   ├── Environment/
│   │   └── APIEnvironment.swift           # APIEnvironmentProtocol + DefaultAPIEnvironment
│   ├── NetworkService/
│   │   ├── Endpoint.swift                 # HTTPMethod, EndpointProtocol, Endpoint, EndpointAnyEncodable
│   │   ├── HTTPNetworkService.swift       # Core service: auth, transport, decode, 401 handling
│   │   ├── MockNetworkService.swift       # Returns canned JSON for testing
│   │   ├── HTTPStatusError.swift           # Typed HTTP status code errors (3xx/4xx/5xx)
│   │   ├── NetworkError.swift             # NetworkError enum
│   │   └── NetworkServiceProtocol.swift   # NetworkServiceProtocol + NetworkServiceEmptyResponseResult
│   ├── Persistence/
│   │   └── KeyChainStore.swift            # KeyChainStoreProtocol, SystemKeyChainStore, MockKeyChainStore
│   └── Transport/
│       ├── CannedResponseTransport.swift  # Fixed-response transport + CannedResponse value type
│       ├── CannedRoutesTransport.swift    # Multi-route transport with match modes
│       ├── HTTPTransportProtocol.swift    # HTTPTransportProtocol (single method)
│       ├── MatchingTransport.swift        # Pattern-guarded transport wrapper
│       ├── ReauthTransport.swift          # 401 intercept → refresh token → retry once
│       ├── RequestPattern.swift           # Regex-based request matching
│       ├── RetryTransport.swift           # Exponential backoff with jitter
│       └── URLSessionTransport.swift      # URLSession adapter
├── Tests/GentleNetworkingTests/
│   └── GentleNetworkingTests.swift        # 111 tests using Swift Testing framework
└── Demo/GentleNetworkingDemo/
    ├── GentleNetworkingDemo/
    │   ├── GentleNetworkingDemoApp.swift   # @main app entry
    │   ├── ContentView.swift              # TabView (Simple / Advanced)
    │   ├── SimpleExampleView.swift        # Inline Endpoint usage
    │   ├── AdvancedExampleView.swift      # Enum-based EndpointProtocol usage
    │   ├── Models.swift                   # Post, User, Comment, TodoItem
    │   └── JSONPlaceholderAPI.swift        # DefaultAPIEnvironment + JSONPlaceholderEndpoint enum
    ├── GentleNetworkingDemoTests/
    │   └── GentleNetworkingDemoTests.swift
    └── fastlane/Fastfile                  # build, package_tests, coverage_xml lanes
```

**20 source files, 1 test file, 1 demo app**

## Layer Summary

```
┌─────────────────────────────────────────────────┐
│  Domain / Consumer Code                         │
│  (EndpointProtocol, APIEnvironmentProtocol)      │
└──────────────────────┬──────────────────────────┘
                       │ uses
┌──────────────────────▼──────────────────────────┐
│  NetworkService                                  │
│  HTTPNetworkService                              │
│  ├── encode endpoint → URLRequest                │
│  ├── authorize (via AuthServiceProtocol)         │
│  ├── send (via HTTPTransportProtocol)            │
│  ├── validate status 200-299                     │
│  ├── handle 401 (via TokenInvalidationHandler)   │
│  └── decode JSON → Model                         │
└──────────────────────┬──────────────────────────┘
                       │ delegates to
┌──────────────────────▼──────────────────────────┐
│  Transport                                       │
│  URLSessionTransport        (production)         │
│  RetryTransport             (backoff + jitter)    │
│  ReauthTransport            (401 → refresh)       │
│  CannedResponseTransport    (single response)    │
│  CannedRoutesTransport      (multi-route)        │
│  MatchingTransport          (pattern guard)       │
└─────────────────────────────────────────────────┘
```

**Flow:** Consumer builds an `EndpointProtocol` value → passes it to `HTTPNetworkService` with an `APIEnvironmentProtocol` → service encodes the endpoint into a `URLRequest`, optionally authorizes it via `AuthServiceProtocol` (which reads tokens from `KeyChainStoreProtocol`), sends it through `HTTPTransportProtocol`, validates the HTTP status, handles 401 via `TokenInvalidationHandler`, and decodes the response.

## Module Dependency Graph

```
HTTPNetworkService
├── HTTPTransportProtocol
│   ├── URLSessionTransport          (URLSession.shared)
│   ├── RetryTransport               (RetryPolicy, any HTTPTransportProtocol)
│   ├── ReauthTransport              (AuthServiceProtocol, any HTTPTransportProtocol)
│   ├── CannedResponseTransport      (CannedResponse)
│   ├── CannedRoutesTransport        (CannedRoute, RequestPattern, CannedResponse)
│   └── MatchingTransport            (RequestPattern, any HTTPTransportProtocol)
├── AuthServiceProtocol
│   └── SystemKeyChainAuthService    (KeyChainStoreProtocol → SystemKeyChainStore)
├── TokenInvalidationHandler         (optional)
├── EndpointProtocol
│   └── Endpoint                     (HTTPMethod, EndpointAnyEncodable)
├── APIEnvironmentProtocol
│   └── DefaultAPIEnvironment
├── JSONDecoder                      (DateDecodingStrategies)
└── JSONEncoder                      (DateEncodingStrategies)

MockNetworkService                   (standalone, implements NetworkServiceProtocol)
MockKeyChainStore                    (standalone actor, implements KeyChainStoreProtocol)
```

## Key Entry Points

| Type | Role |
|------|------|
| `HTTPNetworkService` | Main service — wire this up in production |
| `EndpointProtocol` | Define your API surface as an enum conforming to this |
| `APIEnvironmentProtocol` | Base URL configuration per environment |
| `AuthServiceProtocol` | Token lifecycle (load/save/authorize/delete) |
| `HTTPTransportProtocol` | Swap transports for testing or custom networking |
| `MockNetworkService` | Drop-in replacement for UI previews and unit tests |

## Security

The default `URLSessionTransport` uses `URLSession.shared`, which inherits iOS App Transport Security (TLS 1.2+, system trust store, forward secrecy). For apps with elevated security requirements, `PinningTransport` provides built-in SSL pinning with `PublicKeyPinningEvaluator` and `CertificatePinningEvaluator`. Alternatively, consumers can inject a custom `URLSession` with a pinning delegate into `URLSessionTransport(session:)`, or implement `HTTPTransportProtocol` directly. See [SECURITY.md](SECURITY.md) for details.

## Imports

Every source file imports only `Foundation`. Two files additionally import `Security`:
- `NetworkServiceProtocol.swift`
- `KeyChainStore.swift`

No external dependencies.
