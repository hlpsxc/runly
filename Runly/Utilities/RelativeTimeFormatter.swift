import Foundation

enum RelativeTimeFormatter {
    static func string(from date: Date?, placeholder: String = "—") -> String {
        guard let date else { return placeholder }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    /// Absolute date/time in Beijing (schedule timezone).
    static func absolute(_ date: Date?, placeholder: String = "—") -> String {
        guard let date else { return placeholder }
        return beijingDateTimeFormatter.string(from: date)
    }

    /// Clock time only in Beijing, e.g. `07:00`.
    static func beijingTime(_ date: Date?, placeholder: String = "—") -> String {
        guard let date else { return placeholder }
        return beijingTimeFormatter.string(from: date)
    }

    static func isBeijingToday(_ date: Date) -> Bool {
        ScheduleCalculator.scheduleCalendar.isDateInToday(date)
    }

    static func isBeijingTomorrow(_ date: Date) -> Bool {
        ScheduleCalculator.scheduleCalendar.isDateInTomorrow(date)
    }

    private static let beijingDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = ScheduleCalculator.scheduleTimeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let beijingTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = ScheduleCalculator.scheduleTimeZone
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
