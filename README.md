# GentleNetworking

**GentleNetworking** is a lightweight, Swift-6-ready networking library
designed for modern iOS apps using `async/await`, clean architecture,
and testable abstractions.

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

## 🚀 Basic Usage

### 1. Define an API Environment

``` swift
import GentleNetworking

    let apiEnvironment = DefaultAPIEnvironment(
        baseURL: URL(string: "https://api.company.edu")
    )

```

---

### 2. Create a Network Service

``` swift
    let keyChainAuthService = SystemKeyChainAuthService()
	let networkService = HTTPNetworkService(authService: keyChainAuthService)
```

---

### 3. Authenticate if Needed

``` swift
    struct AuthTokenModel: Decodable, Sendable {
        let token: String
    }

    let signInEndpoint = Endpoint(
    	path: "/signIn", 
        method: .post, 
        body: ["user": "test", "password": "12345"]
    )

    let authTokenModel: AuthTokenModel = try await networkService.request(
        to: signInEndpoint,
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

    let modelEndpoint = Endpoint(
        path: "/model/123", 
        method: .get, 
        requiresAuth: true
    )

	let model: Model = try await networkService.request(
        to: modelEndpoint, 
        via: apiEnvironment
    )
```

---
### 5. Request an Array of Models

``` swift
    let modelsEndpoint = Endpoint(
        path: "/models", 
        method: .get, 
        requiresAuth: true
    )

	let models: [Model] = try await networkService.requestModels(
        to: modelsEndpoint, 
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

## 🔐 License

MIT License
Free for personal and commercial use.

---

## 👤 Author

Built by **Jonathan Ritchey**
Gentle Giraffe Apps
Senior iOS Engineer --- Swift | SwiftUI | Concurrency
