//  Jonathan Ritchey
import Foundation

public enum NetworkError: Error {
    case invalidResponseType
    case invalidStatusCode(Int?)
}
