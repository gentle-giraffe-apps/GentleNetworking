//  Jonathan Ritchey
import Foundation

public struct SystemKeyChainAuthService: AuthServiceProtocol {
    public let keyChainStore: any KeyChainStoreProtocol & Sendable = SystemKeyChainStore()
    public init() {
    }
}
