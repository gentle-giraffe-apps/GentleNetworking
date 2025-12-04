//  Jonathan Ritchey

public protocol TokenInvalidationHandler: Sendable {
    func handleInvalidToken() async
}
