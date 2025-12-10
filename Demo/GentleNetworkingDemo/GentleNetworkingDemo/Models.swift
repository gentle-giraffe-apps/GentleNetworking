//  Jonathan Ritchey

import Foundation

// MARK: - JSONPlaceholder Models

/// A post from JSONPlaceholder API
struct Post: Decodable, Sendable, Identifiable {
    let id: Int
    let userId: Int
    let title: String
    let body: String
}

/// A user from JSONPlaceholder API
struct User: Decodable, Sendable, Identifiable {
    let id: Int
    let name: String
    let username: String
    let email: String
    let phone: String
    let website: String
}

/// A comment from JSONPlaceholder API
struct Comment: Decodable, Sendable, Identifiable {
    let id: Int
    let postId: Int
    let name: String
    let email: String
    let body: String
}

/// A todo item from JSONPlaceholder API
struct TodoItem: Decodable, Sendable, Identifiable {
    let id: Int
    let userId: Int
    let title: String
    let completed: Bool
}
