import Foundation

extension ImportMatcher {
    func normalizedFirstOfMonth(from raw: String?) -> Date? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }

        let monthYearFormats = [
            "MMMM yyyy",
            "MMM yyyy",
            "M/yyyy",
            "MM/yyyy",
            "M-yyyy",
            "MM-yyyy",
            "yyyy-MM",
            "yyyy/M"
        ]

        let fullDateFormats = [
            "yyyy-MM-dd",
            "M/d/yyyy",
            "MM/dd/yyyy",
            "MMM d, yyyy",
            "MMMM d, yyyy"
        ]

        let calendar = Calendar(identifier: .gregorian)

        for format in monthYearFormats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = calendar
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            if let date = formatter.date(from: raw),
               let normalized = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) {
                return normalized
            }
        }

        for format in fullDateFormats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = calendar
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            if let date = formatter.date(from: raw),
               let normalized = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) {
                return normalized
            }
        }

        return nil
    }
}
