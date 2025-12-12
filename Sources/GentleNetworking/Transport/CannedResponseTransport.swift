//  Jonathan Ritchey
import Foundation

public struct CannedResponseTransport: HTTPTransportProtocol {
        
    let dataBody: Data
    let statusCode: Int
    let httpVersion: String?
    let headerFields: [String : String]?
    
    public init(
        data: Data,
        statusCode: Int = 200,
        httpVersion: String? = "HTTP/1.1",
        headerFields: [String : String]? = nil
    ) {
        self.dataBody = data
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

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard let url = request.url else {
            throw URLError(.badURL)
        }
        guard let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: httpVersion, headerFields: headerFields) else {
            throw URLError(.badServerResponse)
        }
        return (dataBody, response)
    }
}
