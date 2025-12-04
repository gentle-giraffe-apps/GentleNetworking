//  Jonathan Ritchey

import Foundation

public struct DateDecodingStrategies {
    public static let iso8601FractionalAndNonFractionalSeconds: JSONDecoder.DateDecodingStrategy = .custom { decoder in
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)

        // formatter with fractional seconds
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // formatter without fractional seconds
        let standard = ISO8601DateFormatter()

        if let date = fractional.date(from: raw) ?? standard.date(from: raw) {
            return date
        }

        throw DecodingError.dataCorrupted(
            .init(
                codingPath: container.codingPath,
                debugDescription: "Invalid ISO8601 date: \(raw)"
            )
        )
    }
}

