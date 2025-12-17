//  Jonathan Ritchey

import Foundation
import GentleNetworking

// MARK: - API Environment

/// JSONPlaceholder API environment configuration
let jsonPlaceholderEnvironment = DefaultAPIEnvironment(
    baseURL: URL(string: "https://jsonplaceholder.typicode.com")
)

// MARK: - Custom API Endpoint Enumeration

/// Type-safe API endpoints for JSONPlaceholder
/// This demonstrates the recommended pattern for defining API endpoints
/// using an enum that conforms to EndpointProtocol.
enum JSONPlaceholderEndpoint {
    // Posts
    case posts
    case post(id: Int)
    case createPost(title: String, body: String, userId: Int)
    case updatePost(id: Int, title: String, body: String, userId: Int)
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
}

extension JSONPlaceholderEndpoint: EndpointProtocol {

    nonisolated var path: String {
        switch self {
        case .posts, .createPost:
            "/posts"
        case .post(let id), .updatePost(let id, _, _, _), .deletePost(let id):
            "/posts/\(id)"
        case .users:
            "/users"
        case .user(let id):
            "/users/\(id)"
        case .comments:
            "/comments"
        case .commentsForPost:
            "/comments"
        case .todos:
            "/todos"
        case .todosForUser:
            "/todos"
        }
    }

    nonisolated var method: HTTPMethod {
        switch self {
        case .posts, .post, .users, .user, .comments, .commentsForPost, .todos, .todosForUser:
            .get
        case .createPost:
            .post
        case .updatePost:
            .put
        case .deletePost:
            .delete
        }
    }

    nonisolated var query: [URLQueryItem]? {
        switch self {
        case .commentsForPost(let postId):
            [URLQueryItem(name: "postId", value: String(postId))]
        case .todosForUser(let userId):
            [URLQueryItem(name: "userId", value: String(userId))]
        default:
            nil
        }
    }

    nonisolated var body: [String: EndpointAnyEncodable]? {
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
        default:
            nil
        }
    }

    nonisolated var requiresAuth: Bool {
        // JSONPlaceholder doesn't require auth, but in a real app you'd
        // return true for endpoints that need authentication
        false
    }
}
