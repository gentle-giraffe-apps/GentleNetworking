//  Jonathan Ritchey

import SwiftUI
import GentleNetworking

/// An advanced example demonstrating GentleNetworking with a custom
/// API endpoint enumeration for type-safe, organized API definitions.
struct AdvancedExampleView: View {
    @State private var users: [User] = []
    @State private var selectedUser: User?
    @State private var userTodos: [TodoItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let networkService = HTTPNetworkService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // User picker section
                if !users.isEmpty {
                    userPickerSection
                }

                // Content section
                contentSection
            }
            .navigationTitle("Advanced Example")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Load Users") {
                        Task {
                            await fetchUsers()
                        }
                    }
                    .disabled(isLoading)
                }
            }
        }
        .task {
            await fetchUsers()
        }
    }

    @ViewBuilder
    private var userPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select a user to view their todos:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("User", selection: $selectedUser) {
                Text("Select user...").tag(nil as User?)
                ForEach(users) { user in
                    Text(user.name).tag(user as User?)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selectedUser) { _, newUser in
                if let user = newUser {
                    Task {
                        await fetchTodos(for: user)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var contentSection: some View {
        if isLoading {
            Spacer()
            ProgressView("Loading...")
            Spacer()
        } else if let error = errorMessage {
            ContentUnavailableView(
                "Error",
                systemImage: "exclamationmark.triangle",
                description: Text(error)
            )
        } else if users.isEmpty {
            ContentUnavailableView(
                "No Users",
                systemImage: "person.3",
                description: Text("Tap 'Load Users' to fetch user data")
            )
        } else if selectedUser == nil {
            ContentUnavailableView(
                "Select a User",
                systemImage: "person.crop.circle.badge.questionmark",
                description: Text("Choose a user from the picker above")
            )
        } else if userTodos.isEmpty {
            ContentUnavailableView(
                "No Todos",
                systemImage: "checklist",
                description: Text("This user has no todos")
            )
        } else {
            todoList
        }
    }

    @ViewBuilder
    private var todoList: some View {
        List(userTodos) { todo in
            HStack(spacing: 12) {
                Image(systemName: todo.completed ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(todo.completed ? .green : .secondary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(todo.title)
                        .font(.body)
                        .strikethrough(todo.completed)
                        .foregroundStyle(todo.completed ? .secondary : .primary)

                    Text("Todo #\(todo.id)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    /// Fetch all users using the custom endpoint enum
    private func fetchUsers() async {
        isLoading = true
        errorMessage = nil

        do {
            // Using the type-safe JSONPlaceholderEndpoint enum
            users = try await networkService.requestModels(
                to: JSONPlaceholderEndpoint.users,
                via: jsonPlaceholderEnvironment
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Fetch todos for a specific user using query parameters
    private func fetchTodos(for user: User) async {
        isLoading = true
        errorMessage = nil
        userTodos = []

        do {
            // Using the endpoint with associated value for filtering
            userTodos = try await networkService.requestModels(
                to: JSONPlaceholderEndpoint.todosForUser(userId: user.id),
                via: jsonPlaceholderEnvironment
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - User Equatable for Picker

extension User: Equatable {
    static func == (lhs: User, rhs: User) -> Bool {
        lhs.id == rhs.id
    }
}

extension User: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

#Preview {
    AdvancedExampleView()
}
