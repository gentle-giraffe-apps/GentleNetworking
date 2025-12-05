//  Jonathan Ritchey
import Foundation

public struct SystemKeyChainAuthService: AuthServiceProtocol {
    public let keyChainStore: any KeyChainStoreProtocol = SystemKeyChainStore()
    public init() {
    }
}
