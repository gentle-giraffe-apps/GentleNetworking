//  IntegrationTests.swift
//  Jonathan Ritchey
//
//  Integration tests that hit jsonplaceholder.typicode.com over real HTTP.
//  These require a network connection and may be skipped in offline CI.
//
//  Tag with .integration so they can be included / excluded independently:
//      swift test --filter IntegrationTests

import Testing
import Foundation
@testable import GentleNetworking

// MARK: - Models

private struct Post: Decodable, Sendable {
    let id: Int
    let userId: Int
    let title: String
    let body: String
}

private struct User: Decodable, Sendable {
    let id: Int
    let name: String
    let username: String
    let email: String
    let phone: String
    let website: String
}

private struct UserAddress: Decodable, Sendable {
    let id: Int
    let name: String
    let username: String
    let email: String
    let address: Address

    struct Address: Decodable, Sendable {
        let street: String
        let suite: String
        let city: String
        let zipcode: String
        let geo: Geo

        struct Geo: Decodable, Sendable {
            let lat: String
            let lng: String
        }
    }
}

private struct Comment: Decodable, Sendable {
    let id: Int
    let postId: Int
    let name: String
    let email: String
    let body: String
}

private struct TodoItem: Decodable, Sendable {
    let id: Int
    let userId: Int
    let title: String
    let completed: Bool
}

private struct Album: Decodable, Sendable {
    let id: Int
    let userId: Int
    let title: String
}

private struct Photo: Decodable, Sendable {
    let id: Int
    let albumId: Int
    let title: String
    let url: String
    let thumbnailUrl: String
}

private struct CreatedPost: Decodable, Sendable {
    let id: Int
    let title: String
    let body: String
    let userId: Int
}

private struct UpdatedPost: Decodable, Sendable {
    let id: Int
    let title: String
    let body: String
    let userId: Int
}

// MARK: - Endpoint

private let environment = DefaultAPIEnvironment(
    baseURL: URL(string: "https://jsonplaceholder.typicode.com")
)

private nonisolated enum API: EndpointProtocol {
    // Posts
    case posts
    case post(id: Int)
    case createPost(title: String, body: String, userId: Int)
    case updatePost(id: Int, title: String, body: String, userId: Int)
    case patchPost(id: Int, title: String)
    case deletePost(id: Int)

    // Users
    case users
    case user(id: Int)

    // Comments
    case comments
    case commentsForPost(postId: Int)

    // Todos
    case todos
    case todosForUser(userId: Int)

    // Albums & Photos
    case albums
    case album(id: Int)
    case photosForAlbum(albumId: Int)

    var path: String {
        switch self {
        case .posts, .createPost:                                    "/posts"
        case .post(let id), .updatePost(let id, _, _, _),
             .patchPost(let id, _), .deletePost(let id):             "/posts/\(id)"
        case .users:                                                 "/users"
        case .user(let id):                                          "/users/\(id)"
        case .comments, .commentsForPost:                            "/comments"
        case .todos, .todosForUser:                                  "/todos"
        case .albums:                                                "/albums"
        case .album(let id):                                         "/albums/\(id)"
        case .photosForAlbum:                                        "/photos"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .posts, .post, .users, .user, .comments, .commentsForPost,
             .todos, .todosForUser, .albums, .album, .photosForAlbum:  .get
        case .createPost:                                              .post
        case .updatePost:                                              .put
        case .patchPost:                                               .patch
        case .deletePost:                                              .delete
        }
    }

    var query: [URLQueryItem]? {
        switch self {
        case .commentsForPost(let postId):
            [URLQueryItem(name: "postId", value: String(postId))]
        case .todosForUser(let userId):
            [URLQueryItem(name: "userId", value: String(userId))]
        case .photosForAlbum(let albumId):
            [URLQueryItem(name: "albumId", value: String(albumId))]
        default:
            nil
        }
    }

    var body: [String: EndpointAnyEncodable]? {
        switch self {
        case .createPost(let title, let body, let userId):
            [
                "title": EndpointAnyEncodable(title),
                "body": EndpointAnyEncodable(body),
                "userId": EndpointAnyEncodable(userId)
            ]
        case .updatePost(_, let title, let body, let userId):
            [
                "title": EndpointAnyEncodable(title),
                "body": EndpointAnyEncodable(body),
                "userId": EndpointAnyEncodable(userId)
            ]
        case .patchPost(_, let title):
            ["title": EndpointAnyEncodable(title)]
        default:
            nil
        }
    }

    var requiresAuth: Bool { false }
}

// MARK: - Shared Service

private struct IntegrationTestAuthService: AuthServiceProtocol {
    let keyChainStore: any KeyChainStoreProtocol = MockKeyChainStore()
}

private let service = HTTPNetworkService(
    transport: URLSessionTransport(session: .shared),
    authService: IntegrationTestAuthService()
)

// MARK: - GET Single Resource

@Suite("Integration – GET single resource")
struct IntegrationGetSingleTests {

    @Test("fetch a single post by id")
    func fetchPost() async throws {
        let post: Post = try await service.request(
            to: API.post(id: 1),
            via: environment
        )
        #expect(post.id == 1)
        #expect(post.userId >= 1)
        #expect(!post.title.isEmpty)
        #expect(!post.body.isEmpty)
    }

    @Test("fetch a single user by id")
    func fetchUser() async throws {
        let user: User = try await service.request(
            to: API.user(id: 1),
            via: environment
        )
        #expect(user.id == 1)
        #expect(!user.name.isEmpty)
        #expect(!user.username.isEmpty)
        #expect(user.email.contains("@"))
    }

    @Test("fetch a single album by id")
    func fetchAlbum() async throws {
        let album: Album = try await service.request(
            to: API.album(id: 1),
            via: environment
        )
        #expect(album.id == 1)
        #expect(album.userId >= 1)
        #expect(!album.title.isEmpty)
    }

    @Test("decode nested JSON – user with address")
    func fetchUserWithAddress() async throws {
        let user: UserAddress = try await service.request(
            to: API.user(id: 1),
            via: environment
        )
        #expect(user.id == 1)
        #expect(!user.address.street.isEmpty)
        #expect(!user.address.city.isEmpty)
        #expect(!user.address.geo.lat.isEmpty)
        #expect(!user.address.geo.lng.isEmpty)
    }
}

// MARK: - GET Collections

@Suite("Integration – GET collections")
struct IntegrationGetCollectionTests {

    @Test("fetch all posts")
    func fetchPosts() async throws {
        let posts: [Post] = try await service.requestModels(
            to: API.posts,
            via: environment
        )
        #expect(posts.count == 100)
        #expect(posts.first?.id == 1)
    }

    @Test("fetch all users")
    func fetchUsers() async throws {
        let users: [User] = try await service.requestModels(
            to: API.users,
            via: environment
        )
        #expect(users.count == 10)
        #expect(users.allSatisfy { $0.email.contains("@") })
    }

    @Test("fetch all todos")
    func fetchTodos() async throws {
        let todos: [TodoItem] = try await service.requestModels(
            to: API.todos,
            via: environment
        )
        #expect(todos.count == 200)
        #expect(todos.contains { $0.completed })
        #expect(todos.contains { !$0.completed })
    }

    @Test("fetch all albums")
    func fetchAlbums() async throws {
        let albums: [Album] = try await service.requestModels(
            to: API.albums,
            via: environment
        )
        #expect(albums.count == 100)
    }

    @Test("fetch all comments")
    func fetchComments() async throws {
        let comments: [Comment] = try await service.requestModels(
            to: API.comments,
            via: environment
        )
        #expect(comments.count == 500)
        #expect(comments.allSatisfy { $0.email.contains("@") || $0.email.contains(".") })
    }
}

// MARK: - Query Parameter Filtering

@Suite("Integration – query parameter filtering")
struct IntegrationQueryParamTests {

    @Test("filter comments by postId")
    func commentsForPost() async throws {
        let comments: [Comment] = try await service.requestModels(
            to: API.commentsForPost(postId: 1),
            via: environment
        )
        #expect(!comments.isEmpty)
        #expect(comments.allSatisfy { $0.postId == 1 })
    }

    @Test("filter todos by userId")
    func todosForUser() async throws {
        let todos: [TodoItem] = try await service.requestModels(
            to: API.todosForUser(userId: 1),
            via: environment
        )
        #expect(!todos.isEmpty)
        #expect(todos.allSatisfy { $0.userId == 1 })
    }

    @Test("filter photos by albumId")
    func photosForAlbum() async throws {
        let photos: [Photo] = try await service.requestModels(
            to: API.photosForAlbum(albumId: 1),
            via: environment
        )
        #expect(!photos.isEmpty)
        #expect(photos.allSatisfy { $0.albumId == 1 })
        #expect(photos.allSatisfy { $0.url.hasPrefix("https://") })
    }
}

// MARK: - POST / PUT / PATCH / DELETE

@Suite("Integration – mutating requests")
struct IntegrationMutationTests {

    @Test("POST creates a resource and returns an id")
    func createPost() async throws {
        let created: CreatedPost = try await service.request(
            to: API.createPost(title: "Integration", body: "Test body", userId: 42),
            via: environment
        )
        #expect(created.id == 101) // JSONPlaceholder always returns 101 for new posts
        #expect(created.title == "Integration")
        #expect(created.body == "Test body")
        #expect(created.userId == 42)
    }

    @Test("PUT replaces a resource")
    func updatePost() async throws {
        let updated: UpdatedPost = try await service.request(
            to: API.updatePost(id: 1, title: "Replaced", body: "New body", userId: 7),
            via: environment
        )
        #expect(updated.id == 1)
        #expect(updated.title == "Replaced")
        #expect(updated.body == "New body")
        #expect(updated.userId == 7)
    }

    @Test("PATCH partially updates a resource")
    func patchPost() async throws {
        let patched: UpdatedPost = try await service.request(
            to: API.patchPost(id: 1, title: "Patched Title"),
            via: environment
        )
        #expect(patched.id == 1)
        #expect(patched.title == "Patched Title")
    }

    @Test("DELETE returns successfully")
    func deletePost() async throws {
        let result = try await service.requestVoid(
            to: API.deletePost(id: 1),
            via: environment
        )
        if case .success(let code) = result {
            #expect(code == 200)
        }
    }
}

// MARK: - Error Handling

@Suite("Integration – error handling")
struct IntegrationErrorTests {

    @Test("404 for a non-existent resource")
    func notFound() async throws {
        let service = HTTPNetworkService(
            transport: URLSessionTransport(session: .shared),
            authService: IntegrationTestAuthService()
        )
        await #expect(throws: NetworkError.self) {
            let _: Post = try await service.request(
                to: API.post(id: 999_999),
                via: environment
            )
        }
    }

    @Test("invalid base URL produces an error")
    func invalidBaseURL() async throws {
        let badEnv = DefaultAPIEnvironment(
            baseURL: URL(string: "https://this-domain-does-not-exist-abc123.example")
        )
        await #expect(throws: Error.self) {
            let _: [Post] = try await service.requestModels(
                to: API.posts,
                via: badEnv
            )
        }
    }
}

// MARK: - Transport Layer

@Suite("Integration – transport layer")
struct IntegrationTransportTests {

    @Test("URLSessionTransport returns valid data and HTTPURLResponse")
    func rawTransport() async throws {
        let transport = URLSessionTransport(session: .shared)
        let url = try #require(URL(string: "https://jsonplaceholder.typicode.com/posts/1"))
        let request = URLRequest(url: url)
        let (data, response) = try await transport.data(for: request)
        #expect(response.statusCode == 200)
        #expect(!data.isEmpty)
        #expect(response.value(forHTTPHeaderField: "Content-Type")?.contains("json") == true)
    }

    @Test("RetryTransport succeeds on first try for healthy endpoint")
    func retryTransportSuccess() async throws {
        let retryService = HTTPNetworkService(
            transport: RetryTransport(
                inner: URLSessionTransport(session: .shared),
                policy: RetryPolicy(maxRetries: 2, baseDelay: 0.1, maxDelay: 1.0, jitter: .full)
            ),
            authService: IntegrationTestAuthService()
        )
        let post: Post = try await retryService.request(
            to: API.post(id: 1),
            via: environment
        )
        #expect(post.id == 1)
    }
}

// MARK: - Endpoint Construction

@Suite("Integration – endpoint URL construction")
struct IntegrationEndpointConstructionTests {

    @Test("ad-hoc Endpoint struct works end-to-end")
    func adHocEndpoint() async throws {
        let endpoint = Endpoint(
            path: "/users/1",
            method: .get
        )
        let user: User = try await service.request(
            to: endpoint,
            via: environment
        )
        #expect(user.id == 1)
    }

    @Test("query parameters round-trip correctly")
    func queryRoundTrip() async throws {
        let endpoint = Endpoint(
            path: "/comments",
            method: .get,
            query: [
                URLQueryItem(name: "postId", value: "1")
            ]
        )
        let comments: [Comment] = try await service.requestModels(
            to: endpoint,
            via: environment
        )
        #expect(!comments.isEmpty)
        #expect(comments.allSatisfy { $0.postId == 1 })
    }
}

// MARK: - Data Integrity

@Suite("Integration – data integrity")
struct IntegrationDataIntegrityTests {

    @Test("same request returns consistent data")
    func consistency() async throws {
        let first: User = try await service.request(
            to: API.user(id: 1),
            via: environment
        )
        let second: User = try await service.request(
            to: API.user(id: 1),
            via: environment
        )
        #expect(first.name == second.name)
        #expect(first.email == second.email)
    }

    @Test("collection ids are unique and sequential")
    func uniqueIds() async throws {
        let posts: [Post] = try await service.requestModels(
            to: API.posts,
            via: environment
        )
        let ids = posts.map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(ids == ids.sorted())
    }

    @Test("relational integrity – post.userId maps to a valid user")
    func relationalIntegrity() async throws {
        let post: Post = try await service.request(
            to: API.post(id: 1),
            via: environment
        )
        let user: User = try await service.request(
            to: API.user(id: post.userId),
            via: environment
        )
        #expect(user.id == post.userId)
    }
}
