# GentleNetworking

Uma biblioteca de networking leve, pronta para Swift 6, projetada para apps iOS modernos usando `async/await`, arquitetura limpa e abstrações testáveis.

> 🌍 **Idioma** · [English](../README.md) · [Español](README.es.md) · Português (Brasil) · [日本語](README.ja.md) · [简体中文](README.zh-CN.md) · [한국어](README.ko.md) · [Русский](README.ru.md)

[![Build](https://github.com/gentle-giraffe-apps/GentleNetworking/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/gentle-giraffe-apps/GentleNetworking/actions/workflows/ci.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/gentle-giraffe-apps/GentleNetworking/branch/main/graph/badge.svg)](https://codecov.io/gh/gentle-giraffe-apps/GentleNetworking)
[![Swift](https://img.shields.io/badge/Swift-6.1+-orange.svg)](https://swift.org)
[![SPM Compatible](https://img.shields.io/badge/SPM-Compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![Platform](https://img.shields.io/badge/platform-iOS%2017%2B-blue)](https://developer.apple.com/ios/)
![Commit activity](https://img.shields.io/github/commit-activity/y/gentle-giraffe-apps/GentleNetworking)
![Last commit](https://img.shields.io/github/last-commit/gentle-giraffe-apps/GentleNetworking)
[![DeepSource Static Analysis](https://img.shields.io/badge/DeepSource-Static%20Analysis-0A2540?logo=deepsource&logoColor=white)](https://deepsource.io/)
[![DeepSource](https://app.deepsource.com/gh/gentle-giraffe-apps/GentleNetworking.svg/?label=active+issues&show_trend=true)](https://app.deepsource.com/gh/gentle-giraffe-apps/GentleNetworking/)

---

## ✨ Funcionalidades

- ✅ API nativa com `async/await`
- ✅ Camada de networking baseada em protocolos, totalmente mockável
- ✅ Decodificação tipada de request / response
- ✅ Compatível com Swift 6 + Swift Concurrency
- ✅ Projetada para MVVM / Clean Architecture
- ✅ Zero dependências de terceiros
- ✅ Transports com respostas predefinidas para testes

💬 **[Participe da discussão. Feedback e perguntas são bem-vindos](https://github.com/gentle-giraffe-apps/GentleNetworking/discussions)**

---

## App de Demonstração

Uma app de demonstração em SwiftUI executável está incluída neste repositório usando uma referência local ao pacote.

### Como Executar
1. Clone o repositório:
   ```bash
   git clone https://github.com/gentle-giraffe-apps/GentleNetworking.git
   ```
2. Abra o projeto de demonstração:
   ```
   Demo/GentleNetworkingDemo/GentleNetworkingDemo.xcodeproj
   ```
3. Selecione um simulador com iOS 17+.
4. Compile e execute (⌘R).

O projeto vem pré-configurado com uma referência local ao pacote Swift `GentleNetworking` e deve funcionar sem configuração adicional.

---

## 📦 Instalação (Swift Package Manager)

### Via Xcode

1. Abra seu projeto no Xcode
2. Vá em **File → Add Packages...**
3. Insira a URL do repositório: `https://github.com/gentle-giraffe-apps/GentleNetworking.git`
4. Escolha uma regra de versão (ou `main` durante o desenvolvimento)
5. Adicione o produto **GentleNetworking** ao seu target

### Via Package.swift

Adicione a dependência ao seu `Package.swift`:

``` swift
dependencies: [
    .package(url: "https://github.com/gentle-giraffe-apps/GentleNetworking.git", from: "1.0.0")
]
```

Em seguida, adicione `"GentleNetworking"` ao target que precisar:

``` swift
.target(
    name: "YourApp",
    dependencies: ["GentleNetworking"]
)
```

---

## Qualidade e Ferramentas

Este projeto aplica controles de qualidade via CI e análise estática:

- **CI:** Todos os commits em `main` devem passar nas verificações do GitHub Actions
- **Análise estática:** DeepSource é executado em cada commit em `main`.
  O badge indica o número atual de issues de análise estática pendentes.
- **Cobertura de testes:** Codecov reporta a cobertura de linhas para a branch `main`

<sub><strong>Snapshot do Codecov</strong></sub><br/>
<a href="https://codecov.io/gh/gentle-giraffe-apps/GentleNetworking"><img src="https://codecov.io/gh/gentle-giraffe-apps/GentleNetworking/graphs/icicle.svg" height="80" style="max-width: 420px;" alt="Gráfico de cobertura do Codecov" /></a>

Essas verificações são projetadas para manter o sistema seguro à medida que evolui.

---

## Arquitetura

GentleNetworking é centrado em um único `HTTPNetworkService` baseado em protocolos que coordena as requisições usando abstrações injetadas de endpoint, ambiente e autenticação.

```mermaid
flowchart TB
    HTTP["HTTPNetworkService<br/><br/>- request(...)"]

    Endpoint["EndpointProtocol<br/><br/><br/>"]
    Env["APIEnvironmentProtocol<br/><br/><br/>"]
    Auth["AuthServiceProtocol<br/><br/><br/>"]

    HTTP --> Endpoint
    HTTP --> Env
    HTTP -->|injetado| Auth
```

### Endpoint

```mermaid
flowchart TB
    APIEndpoint["APIEndpoint enum<br/><br/>case endpoint1<br/>…<br/>endpointN"]

    EndpointProtocol["EndpointProtocol<br/><br/>- path<br/>- method<br/>- query<br/>- body<br/>- requiresAuth"]

    APIEndpoint -->|conforma a| EndpointProtocol
```

## 🚀 Uso Básico

### 1. Definir uma API e Endpoints

``` swift
import GentleNetworking

let apiEnvironment = DefaultAPIEnvironment(
    baseURL: URL(string: "https://api.company.com")
)

nonisolated enum APIEndpoint: EndpointProtocol {
    case signIn(username: String, password: String)
    case model(id: Int)
    case models

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

    var body: [String: EndpointAnyEncodable]? {
        switch self {
        case .signIn(let username, let password): [
            "username": EndpointAnyEncodable(username),
            "password": EndpointAnyEncodable(password)
        ]
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

### 2. Criar um Network Service

``` swift
let networkService = HTTPNetworkService()
```

---

### 3. Autenticar se Necessário

`SystemKeyChainAuthService` é a implementação integrada do `AuthServiceProtocol`. Ele armazena um token Bearer no keychain do sistema e o anexa automaticamente às requisições de endpoints onde `requiresAuth` é `true`.

``` swift
let keyChainAuthService = SystemKeyChainAuthService()

struct AuthTokenModel: Decodable, Sendable {
    let token: String
}

let authTokenModel: AuthTokenModel = try await networkService.request(
    to: .signIn(username: "user", password: "pass"),
    via: apiEnvironment
)

try await keyChainAuthService.saveAccessToken(
    authTokenModel.token
)
```

---
### 4. Solicitar um Modelo

Use `request` para decodificar um único objeto da resposta:

``` swift
struct Model: Decodable, Sendable {
    let id: Int
    let property: String
}

let model: Model = try await networkService.request(
    to: .model(id: 123),
    via: apiEnvironment
)
```

---
### 5. Solicitar um Array de Modelos

Use `requestModels` para decodificar um array de objetos da resposta:

``` swift
let models: [Model] = try await networkService.requestModels(
    to: .models,
    via: apiEnvironment
)
```

---

## 🧪 Testes

GentleNetworking fornece uma abstração na camada de transporte para facilitar o mocking em testes.

### CannedResponseTransport

Retorna uma resposta fixa para qualquer requisição:

``` swift
let transport = CannedResponseTransport(
    string: #"{"id": 1, "title": "Test"}"#,
    statusCode: 200
)

let networkService = HTTPNetworkService(transport: transport)
```

### CannedRoutesTransport

Associa requisições por método e padrão de rota para cenários de teste mais realistas:

``` swift
let transport = CannedRoutesTransport(routes: [
    CannedRoute(
        pattern: RequestPattern(method: .get, path: "/api/models"),
        response: CannedResponse(string: #"[{"id": 1}]"#)
    ),
    CannedRoute(
        pattern: RequestPattern(method: .post, pathRegex: "^/api/model/\\d+$"),
        response: CannedResponse(string: #"{"success": true}"#)
    )
])

let networkService = HTTPNetworkService(transport: transport)
```

---

## 🔒 Segurança

GentleNetworking utiliza o App Transport Security (ATS) da Apple para proteção da camada de transporte — TLS 1.2+, validação de certificados, forward secrecy — tudo aplicado pelo sistema operacional e habilitado por padrão.

### Pinning de Certificado SSL

Para apps com requisitos de segurança elevados, use o `PinningTransport` integrado com pinning de chave pública ou de certificado:

``` swift
import CryptoKit

// Pinning de chave pública (recomendado — sobrevive a renovações de certificado)
let service = HTTPNetworkService(
    transport: PinningTransport(
        pinnedDomains: [
            "api.example.com": PublicKeyPinningEvaluator(
                pinnedKeyHashes: [primaryKeyHash, backupKeyHash]
            )
        ]
    )
)

// Pinning de certificado (mais simples, falha a cada renovação)
let service = HTTPNetworkService(
    transport: PinningTransport(
        pinnedDomains: [
            "api.example.com": CertificatePinningEvaluator(
                pinnedCertificates: [certDERData]
            )
        ]
    )
)
```

Domínios sem pinning utilizam a validação padrão do ATS. Implemente `ServerTrustEvaluator` para lógica de confiança personalizada.

Consulte [SECURITY.md](SECURITY.md) para o guia completo incluindo melhores práticas, avaliadores personalizados e abordagens alternativas.

---

## 🧭 Filosofia de Design

GentleNetworking é construído em torno de:

- ✅ Previsibilidade acima de mágica
- ✅ Design baseado em protocolos
- ✅ Injeção de dependências explícita
- ✅ Concorrência moderna do Swift
- ✅ Testabilidade por padrão
- ✅ Superfície de API pequena com garantias sólidas

É intencionalmente mínimo e evita sobre-abstrair ou ocultar o comportamento de networking.

---

## 🤖 Nota sobre Ferramentas

Partes da redação e do refinamento editorial neste repositório foram acelerados usando modelos de linguagem grandes (incluindo ChatGPT, Claude e Gemini) sob design humano direto, validação e aprovação final. Todas as decisões técnicas, código e conclusões arquiteturais são de autoria e verificação do mantenedor do repositório.

---

## 🔐 Licença

Licença MIT
Livre para uso pessoal e comercial.

---

## 👤 Autor

Criado por **Jonathan Ritchey**
Gentle Giraffe Apps
Senior iOS Engineer --- Swift | SwiftUI | Concurrency

![Visitors](https://api.visitorbadge.io/api/visitors?path=https%3A%2F%2Fgithub.com%2Fgentle-giraffe-apps%2FGentleNetworking)
