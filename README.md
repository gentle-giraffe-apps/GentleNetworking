# GentleNetworking

**GentleNetworking** is a lightweight, Swift-6-ready networking library
designed for modern iOS apps using `async/await`, clean architecture,
and testable abstractions.

[![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![SPM Compatible](https://img.shields.io/badge/SPM-Compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![Platforms](https://img.shields.io/badge/platforms-iOS%2017%2B%20%7C%20macOS%2014%2B-blue)](https://developer.apple.com/)
[![Coverage](https://img.shields.io/badge/coverage-94%25-brightgreen.svg)](#)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## ✨ Features

- ✅ Native `async/await` API
- ✅ Protocol-based, fully mockable networking layer
- ✅ Typed request / response decoding
- ✅ Swift 6 + Swift Concurrency friendly
- ✅ Designed for MVVM / Clean Architecture
- ✅ Zero third-party dependencies

---

## 📦 Installation (Swift Package Manager)

### Via Xcode

1. Open your project in Xcode
2. Go to **File → Add Packages...**
3. Enter the repository URL: `https://github.com/gentle-giraffe-apps/GentleNetworking.git`
4. Choose a version rule (or `main` while developing)
5. Add the **GentleNetworking** product to your app target

---

## Architecture

GentleNetworking is centered around a single, protocol-driven `HTTPNetworkService` that coordinates requests using injected endpoint, environment, and authentication abstractions.



```mermaid
flowchart TB
    HTTP["HTTPNetworkService<br/><br/>- request(...)"]

    Endpoint["EndpointProtocol<br/><br/><br/>"]
    Env["APIEnvironmentProtocol<br/><br/><br/>"]
    Auth["AuthServiceProtocol<br/><br/><br/>"]

    HTTP --> Endpoint
    HTTP --> Env
    HTTP -->|injected| Auth
```

### Endpoint

```mermaid
flowchart TB
    APIEndpoint["APIEndpoint enum<br/><br/>case endpoint1<br/>…<br/>endpointN"]

    EndpointProtocol["EndpointProtocol<br/><br/>- path<br/>- method<br/>- query<br/>- body<br/>- requiresAuth"]

    APIEndpoint -->|conforms to| EndpointProtocol
```

## 🚀 Basic Usage

### 1. Define an API and Endpoints

``` swift
import GentleNetworking

    let apiEnvironment = DefaultAPIEnvironment(
        baseURL: URL(string: "https://api.company.com")
    )

    enum APIEndpoint {
        case signIn(username: String, password: String)
        case model(id: Int)
        case models
    }

    extension APIEndpoint: EndpointProtocol {
    
        var path: String {
            switch self {
            case .signIn: "/api/signIn"
            case .model(let id): "/api/model/\(id)"
            case .models: "/api/models"
            }
        }

        var method: HTTPMethod {
            switch self {
            case .signIn: .post
            case .model, .models: .get
            }
        }

        var query: [URLQueryItem]? {
            switch self {
            case .signIn, .model, .models: nil
            }
        }

        var body: [String: Any]? {
            switch self {
            case .signIn(let username, let password): [ "username": username, "password": password ]
            case .model, .models: nil
            }
        }
        
        var requiresAuth: Bool {
            switch self {
            case .model, .models: true
            case .signIn(username: _, password: _): false
            }
        }
    }

```

---

### 2. Create a Network Service

``` swift
	let networkService = HTTPNetworkService(authService: keyChainAuthService)
```

---

### 3. Authenticate if Needed

``` swift
    let keyChainAuthService = SystemKeyChainAuthService()

    struct AuthTokenModel: Decodable, Sendable {
        let token: String
    }

    let authTokenModel: AuthTokenModel = try await networkService.request(
        to: .signIn(username, password),
        via: apiEnvironment
    )

    try keyChainAuthService.saveAccessToken(
        authTokenModel.token
    )
```

---
### 4. Request a Model

``` swift
    struct Model: Decodable, Sendable {
        let id: Int
        let property: String
    }

	let model: Model = try await networkService.request(
        to: .model, 
        via: apiEnvironment
    )
```

---
### 5. Request an Array of Models

``` swift
	let models: [Model] = try await networkService.requestModels(
        to: .models, 
        via: apiEnvironment
    )
```

---

## 🧭 Design Philosophy

GentleNetworking is built around:

- ✅ Predictability over magic
- ✅ Protocol-driven design
- ✅ Explicit dependency injection
- ✅ Modern Swift concurrency
- ✅ Testability by default
- ✅ Small surface area with strong guarantees

It is intentionally minimal and avoids over-abstracting or hiding
networking behavior.

---

## 📱 Platform Support

- iOS 17+
- macOS 14+

Additional platforms can be added easily if needed.

---

## 🤖 Tooling Note

Portions of drafting and editorial refinement in this repository were accelerated using large language models (including ChatGPT, Claude, and Gemini) under direct human design, validation, and final approval. All technical decisions, code, and architectural conclusions are authored and verified by the repository maintainer.

---

## 🔐 License

MIT License
Free for personal and commercial use.

---

## 👤 Author

Built by **Jonathan Ritchey**
Gentle Giraffe Apps
Senior iOS Engineer --- Swift | SwiftUI | Concurrency
