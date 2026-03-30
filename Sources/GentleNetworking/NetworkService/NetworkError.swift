//  Jonathan Ritchey
import Foundation

public enum NetworkError: Error, Sendable {
    case invalidResponseType
    @available(*, deprecated, message: "Use httpStatusError(_:) instead")
    case invalidStatusCode(Int?)
    case httpStatusError(HTTPStatusError)
}
