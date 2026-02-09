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
│   │   ├── NetworkError.swift             # NetworkError enum
│   │   └── NetworkServiceProtocol.swift   # NetworkServiceProtocol + NetworkServiceEmptyResponseResult
│   ├── Persistence/
│   │   └── KeyChainStore.swift            # KeyChainStoreProtocol, SystemKeyChainStore, MockKeyChainStore
│   └── Transport/
│       ├── CannedResponseTransport.swift  # Fixed-response transport + CannedResponse value type
│       ├── CannedRoutesTransport.swift    # Multi-route transport with match modes
│       ├── HTTPTransportProtocol.swift    # HTTPTransportProtocol (single method)
│       ├── MatchingTransport.swift        # Pattern-guarded transport wrapper
│       ├── RequestPattern.swift           # Regex-based request matching
│       └── URLSessionTransport.swift      # URLSession adapter
├── Tests/GentleNetworkingTests/
│   └── GentleNetworkingTests.swift        # 91 tests using Swift Testing framework
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

**17 source files, 1 test file (91 tests), 1 demo app**

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

## Imports

Every source file imports only `Foundation`. Two files additionally import `Security`:
- `NetworkServiceProtocol.swift`
- `KeyChainStore.swift`

No external dependencies.
