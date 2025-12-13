//  Jonathan Ritchey
import Foundation

public struct CannedRoute: Sendable {
    public let pattern: RequestPattern
    public let response: CannedResponse
}
