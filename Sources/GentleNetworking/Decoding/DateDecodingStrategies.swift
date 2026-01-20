//  Jonathan Ritchey

import Foundation

public enum DateDecodingStrategies {
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

public enum DateEncodingStrategies {

    /// Encodes dates as ISO-8601 with fractional seconds.
    /// Example:
    /// - 2024-01-01T12:34:56.789Z
    public static let iso8601FractionalSeconds: JSONEncoder.DateEncodingStrategy = .custom { date, encoder in
        var container = encoder.singleValueContainer()

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let string = formatter.string(from: date)
        try container.encode(string)
    }
}
