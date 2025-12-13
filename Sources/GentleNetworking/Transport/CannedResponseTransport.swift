//  Jonathan Ritchey
import Foundation

public struct CannedResponse: Sendable {
    
    public enum Error: Swift.Error, Sendable {
        case failedToCreateHTTPURLResponse
    }
    
    public let data: Data
    public let statusCode: Int
    public let httpVersion: String?
    public let headerFields: [String: String]?

    public init(
        data: Data,
        statusCode: Int = 200,
        httpVersion: String? = "HTTP/1.1",
        headerFields: [String : String]? = nil
    ) {
        self.data = data
        self.statusCode = statusCode
        self.httpVersion = httpVersion
        self.headerFields = headerFields
    }
    
    public init(
        string: String,
        encoding: String.Encoding = .utf8,
        statusCode: Int = 200,
        httpVersion: String? = "HTTP/1.1",
        headerFields: [String : String]? = nil
    ) {
        guard let data = string.data(using: encoding) else {
            preconditionFailure("Failed to encode string using \(encoding)")
        }

        self.init(
            data: data,
            statusCode: statusCode,
            httpVersion: httpVersion,
            headerFields: headerFields
        )
    }
    
    public func makeResponse(url: URL) throws -> HTTPURLResponse {
        guard let urlResponse = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: httpVersion, headerFields: headerFields) else {
            throw Error.failedToCreateHTTPURLResponse
        }
        return urlResponse
    }
}

public struct CannedResponseTransport: HTTPTransportProtocol {
    
    public enum Error: Swift.Error, Sendable {
        case missingRequestURL
    }
    
    public let cannedResponse: CannedResponse

    public init(cannedResponse: CannedResponse) {
        self.cannedResponse = cannedResponse
    }
    
    public init(
        string: String,
        encoding: String.Encoding = .utf8,
        statusCode: Int = 200,
        headerFields: [String: String]? = nil
    ) {
        self.init(
            cannedResponse: .init(
                string: string,
                encoding: encoding,
                statusCode: statusCode,
                headerFields: headerFields
            )
        )
    }
    
    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard let url = request.url else {
            throw Error.missingRequestURL
        }
        let response = try cannedResponse.makeResponse(url: url)
        return (cannedResponse.data, response)
    }
}
