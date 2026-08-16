import Foundation

enum RelativeTimeFormatter {
    static func string(from date: Date?, placeholder: String = "—") -> String {
        guard let date else { return placeholder }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    static func absolute(_ date: Date?, placeholder: String = "—") -> String {
        guard let date else { return placeholder }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
