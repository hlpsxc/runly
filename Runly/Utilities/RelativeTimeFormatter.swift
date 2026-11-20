import Foundation

enum RelativeTimeFormatter {
    static func string(from date: Date?, placeholder: String = "—") -> String {
        guard let date else { return placeholder }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    /// Absolute date/time in the task schedule timezone (legacy nil → Asia/Shanghai).
    static func absolute(
        _ date: Date?,
        timeZoneIdentifier: String? = nil,
        placeholder: String = "—"
    ) -> String {
        guard let date else { return placeholder }
        return dateTimeFormatter(timeZoneIdentifier: timeZoneIdentifier).string(from: date)
    }

    /// Clock time only, e.g. `07:00`, in the task schedule timezone.
    static func clockTime(
        _ date: Date?,
        timeZoneIdentifier: String? = nil,
        placeholder: String = "—"
    ) -> String {
        guard let date else { return placeholder }
        return timeFormatter(timeZoneIdentifier: timeZoneIdentifier).string(from: date)
    }

    /// Compatibility alias for call sites that still say “Beijing time”.
    static func beijingTime(_ date: Date?, placeholder: String = "—") -> String {
        clockTime(date, timeZoneIdentifier: ScheduleCalculator.legacyTimeZoneIdentifier, placeholder: placeholder)
    }

    static func isToday(_ date: Date, timeZoneIdentifier: String? = nil) -> Bool {
        ScheduleCalculator.scheduleCalendar(timeZoneIdentifier: timeZoneIdentifier).isDateInToday(date)
    }

    static func isTomorrow(_ date: Date, timeZoneIdentifier: String? = nil) -> Bool {
        ScheduleCalculator.scheduleCalendar(timeZoneIdentifier: timeZoneIdentifier).isDateInTomorrow(date)
    }

    static func isBeijingToday(_ date: Date) -> Bool {
        isToday(date, timeZoneIdentifier: ScheduleCalculator.legacyTimeZoneIdentifier)
    }

    static func isBeijingTomorrow(_ date: Date) -> Bool {
        isTomorrow(date, timeZoneIdentifier: ScheduleCalculator.legacyTimeZoneIdentifier)
    }

    private static func dateTimeFormatter(timeZoneIdentifier: String?) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = ScheduleCalculator.timeZone(for: timeZoneIdentifier)
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }

    private static func timeFormatter(timeZoneIdentifier: String?) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = ScheduleCalculator.timeZone(for: timeZoneIdentifier)
        formatter.dateFormat = "HH:mm"
        return formatter
    }
}
