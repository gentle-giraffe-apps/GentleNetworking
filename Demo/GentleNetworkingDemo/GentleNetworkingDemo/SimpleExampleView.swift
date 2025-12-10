//  Jonathan Ritchey

import SwiftUI
import GentleNetworking

/// A simple example demonstrating basic GentleNetworking usage
/// using the built-in Endpoint struct for quick, one-off requests.
struct SimpleExampleView: View {
    @State private var posts: [Post] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    // Create the network service (no auth needed for this demo)
    private let networkService = HTTPNetworkService()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading posts...")
                } else if let error = errorMessage {
                    ContentUnavailableView(
                        "Error",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if posts.isEmpty {
                    ContentUnavailableView(
                        "No Posts",
                        systemImage: "doc.text",
                        description: Text("Tap the button to fetch posts")
                    )
                } else {
                    List(posts) { post in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(post.title)
                                .font(.headline)
                            Text(post.body)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Simple Example")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Fetch Posts") {
                        Task {
                            await fetchPosts()
                        }
                    }
                    .disabled(isLoading)
                }
            }
        }
    }

    /// Fetch posts using the simple Endpoint struct
    /// This approach is ideal for quick, ad-hoc requests
    private func fetchPosts() async {
        isLoading = true
        errorMessage = nil

        // Define the endpoint inline using the Endpoint struct
        let endpoint = Endpoint(
            path: "/posts",
            method: .get,
            query: [URLQueryItem(name: "_limit", value: "10")],
            requiresAuth: false
        )

        // Define the environment
        let environment = DefaultAPIEnvironment(
            baseURL: URL(string: "https://jsonplaceholder.typicode.com")
        )

        do {
            // Make the request - GentleNetworking handles decoding
            posts = try await networkService.requestModels(
                to: endpoint,
                via: environment
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    SimpleExampleView()
}
