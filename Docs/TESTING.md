# Testing

## Overview

- **Single test file**: `Tests/GentleNetworkingTests/GentleNetworkingTests.swift`
- **Framework**: Swift Testing (`@Suite`, `@Test`, `#expect`) — not XCTest

## Running Tests

```bash
# SwiftPM (no keychain entitlements)
swift test

# Xcode (with simulator, keychain entitlements available)
xcodebuild test \
  -scheme GentleNetworking \
  -sdk iphonesimulator \
  -destination "platform=iOS Simulator,name=iPhone 17"

# Fastlane (build + test + coverage)
cd Demo/GentleNetworkingDemo
bundle exec fastlane build          # compile package + demo app
bundle exec fastlane package_tests  # run tests (no recompilation)
bundle exec fastlane coverage_xml   # convert results to Cobertura XML
```

## Suite / Test Pattern

```swift
@Suite("HTTPMethod")
struct HTTPMethodTests {
    @Test func rawValues() {
        #expect(HTTPMethod.get.rawValue == "GET")
    }
}
```

- One `@Suite` per public type or feature area
- `@Test func` for each assertion group
- `#expect(...)` for assertions, `#expect(throws:)` for error expectations

## Test Suites

| Suite | What it covers |
|-------|---------------|
| `HTTPMethodTests` | Enum raw values |
| `EndpointTests` | Init, URL construction, method, query, body, content type |
| `APIEnvironmentTests` | Base URL, nil, equatability |
| `MockKeyChainStoreTests` | Save/read/delete/overwrite/multi-key |
| `KeyChainStoreErrorTests` | Error case instantiation |
| `SystemKeyChainStoreEnvironmentTests` | SwiftPM vs host-app keychain behavior |
| `AuthServiceTests` | Header defaults, token CRUD, authorize, missing token |
| `DateDecodingStrategiesTests` | Standard ISO8601, fractional, invalid, fallback |
| `DateEncodingStrategiesTests` | Fractional seconds encoding |
| `MockNetworkServiceTests` | Decode single/array, void, delay, error, custom decoder |
| `NetworkErrorTests` | Status code storage, nil, Error conformance |
| `NetworkServiceEmptyResponseResultTests` | Success code storage |
| `HTTPNetworkServiceTests` | Full integration via MockURLProtocol (`.serialized`) |
| `RequestPatternTests` | Method/host/path matching, regex, literal escaping |
| `CannedRoutesTransportTests` | First-match, unique-match, no-match, missing URL |
| `CannedResponseTransportTests` | Response, missing URL, custom headers |
| `MatchingTransportTests` | Match pass-through, mismatch error |
| `CustomEndpointTests` | Enum-based EndpointProtocol (GET, POST, DELETE) |

## Mock Inventory

### Public (shipped in library)

| Mock | Kind | Purpose |
|------|------|---------|
| `MockNetworkService` | `struct` | Returns pre-loaded JSON; simulates latency via `duration` |
| `MockKeyChainStore` | `actor` | In-memory `[String: String]` dictionary |

### Test-only (defined in test file)

| Mock | Kind | Purpose |
|------|------|---------|
| `MockAuthService` | `struct` | Conforms to `AuthServiceProtocol` with `MockKeyChainStore` |
| `MockURLProtocol` | `final class` | Intercepts `URLSession` requests via static `requestHandler` closure |
| `MockTokenInvalidationHandler` | `final class` | Tracks whether `handleInvalidToken()` was called |

## Transport-Level Mocking

For tests that don't need `URLSession`, use canned transports:

```swift
// Single fixed response
let transport = CannedResponseTransport(string: "{\"id\": 1}", statusCode: 200)
let service = HTTPNetworkService(transport: transport, authService: MockAuthService())

// Multiple routes
let transport = CannedRoutesTransport(routes: [
    CannedRoute(pattern: RequestPattern(method: .get, path: "/users"), response: usersResponse),
    CannedRoute(pattern: RequestPattern(method: .post, path: "/users"), response: createResponse),
])
```

## URLProtocol Mocking

`HTTPNetworkServiceTests` uses `MockURLProtocol` to intercept real `URLSession` traffic:

```swift
@Suite("HTTPNetworkService", .serialized)  // serialized because URLProtocol is global state
struct HTTPNetworkServiceTests {
    // Setup: register MockURLProtocol, configure session, set requestHandler
}
```

**`.serialized`** is required because `MockURLProtocol.requestHandler` is static mutable state.

## `@unchecked Sendable`

Used **only in tests** for mock types with mutable state that need to conform to `Sendable`:

```swift
final class MockTokenInvalidationHandler: TokenInvalidationHandler, @unchecked Sendable {
    var invalidationCalled = false
    func handleInvalidToken() async { invalidationCalled = true }
}
```

Rationale: test mocks are single-threaded in practice; `@unchecked` avoids boilerplate actor isolation for simple flag tracking.

## Environment Detection

```swift
private enum TestEnvironment {
    static var isSwiftPMTest: Bool {
        ProcessInfo.processInfo.environment["XCTestBundlePath"] == nil
    }
}
```

Used in `SystemKeyChainStoreEnvironmentTests` to branch on whether keychain entitlements are available:
- **SwiftPM** (`swift test`): no entitlements → expects `-34018` error
- **Host app** (Xcode): entitlements available → expects success
