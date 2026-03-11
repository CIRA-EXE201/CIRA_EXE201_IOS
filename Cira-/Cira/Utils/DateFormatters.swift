import Foundation

enum DateFormatters {
    /// ISO8601 with fractional seconds — used for Supabase timestamps
    static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    
    /// ISO8601 WITHOUT fractional seconds — fallback for Supabase timestamps
    static let iso8601NoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    
    /// Parse ISO8601 string trying both formats (with and without fractional seconds)
    static func parseISO8601(_ string: String) -> Date? {
        return iso8601.date(from: string) ?? iso8601NoFraction.date(from: string)
    }
    
    /// Relative date formatter — "2 hours ago", "yesterday"
    static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()
}
