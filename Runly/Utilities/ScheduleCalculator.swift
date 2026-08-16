import Foundation

enum ScheduleCalculator {
    static func nextRunDate(
        type: ScheduleType,
        expression: String,
        after: Date = .now,
        enabled: Bool
    ) -> Date? {
        guard enabled else { return nil }
        let expr = expression.trimmingCharacters(in: .whitespacesAndNewlines)

        switch type {
        case .once:
            if let date = parseAbsoluteDate(expr), date > after {
                return date
            }
            return nil
        case .interval:
            guard let seconds = parseIntervalSeconds(expr) else { return nil }
            return after.addingTimeInterval(TimeInterval(seconds))
        case .daily:
            return nextDaily(expr, after: after)
        case .weekly:
            return nextWeekly(expr, after: after)
        case .cron:
            return nextFromCron(expr, after: after)
        }
    }

    /// Seconds for launchd StartInterval.
    static func intervalSeconds(expression: String) -> Int? {
        parseIntervalSeconds(expression.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static func parseDailyTime(_ expression: String) -> (hour: Int, minute: Int)? {
        let expr = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        // Accept "9:05", "09:05", "09:05:00"
        let parts = expr.split(separator: ":")
        guard parts.count >= 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }
        return (hour, minute)
    }

    static func parseWeekly(_ expression: String) -> (weekday: Int, hour: Int, minute: Int)? {
        // Formats: "Mon 09:00", "1 09:00" (launchd weekday: 0=Sunday … 6=Saturday)
        let expr = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = expr.split(whereSeparator: \.isWhitespace)
        guard tokens.count >= 2 else { return nil }
        guard let time = parseDailyTime(tokens.dropFirst().joined(separator: " "))
                ?? parseDailyTime(String(tokens[1])) else { return nil }

        let dayToken = tokens[0].lowercased()
        let weekday: Int?
        if let number = Int(dayToken), (0...7).contains(number) {
            // Accept 0/7 = Sunday … 6 = Saturday (launchd uses 0=Sunday)
            weekday = number == 7 ? 0 : number
        } else {
            weekday = weekdayAbbreviationMap[dayToken]
        }
        guard let weekday else { return nil }
        return (weekday, time.hour, time.minute)
    }

    /// Parses a one-shot absolute datetime (minute precision).
    static func parseOnceDate(_ expression: String) -> Date? {
        parseAbsoluteDate(expression.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static func formatOnceDate(_ date: Date) -> String {
        onceFormatter.string(from: date)
    }

    static func formatDailyTime(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }

    static func formatWeekly(weekday: Int, hour: Int, minute: Int) -> String {
        let day = weekdayAbbreviations[weekday] ?? "Mon"
        return "\(day) \(formatDailyTime(hour: hour, minute: minute))"
    }

    /// Date whose hour/minute match a daily expression (for DatePicker bindings).
    static func dateForDailyTime(_ expression: String, reference: Date = .now) -> Date {
        let time = parseDailyTime(expression) ?? (9, 0)
        return date(settingHour: time.hour, minute: time.minute, of: reference)
    }

    static func date(settingHour hour: Int, minute: Int, of reference: Date = .now) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = .current
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: reference) ?? reference
    }

    /// Default one-shot: next whole minute at least one minute from now.
    static func defaultOnceDate(after: Date = .now) -> Date {
        let calendar = Calendar.current
        let nextMinute = calendar.date(byAdding: .minute, value: 1, to: after) ?? after.addingTimeInterval(60)
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: nextMinute)
        return calendar.date(from: comps) ?? nextMinute
    }

    /// launchd weekday 0…6 → short English label used in expressions.
    static let weekdayAbbreviations = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    // MARK: - Private

    private static let weekdayAbbreviationMap: [String: Int] = [
        "sun": 0, "sunday": 0,
        "mon": 1, "monday": 1,
        "tue": 2, "tues": 2, "tuesday": 2,
        "wed": 3, "wednesday": 3,
        "thu": 4, "thur": 4, "thurs": 4, "thursday": 4,
        "fri": 5, "friday": 5,
        "sat": 6, "saturday": 6
    ]

    private static let onceFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    private static func parseIntervalSeconds(_ expression: String) -> Int? {
        let lower = expression.lowercased()
        if lower.isEmpty || lower == "every day" {
            return 86_400
        }

        let pattern = #/(?:every\s+)?(\d+)\s*(second|seconds|sec|s|minute|minutes|min|m|hour|hours|hr|h|day|days|d)?/#
        if let match = lower.firstMatch(of: pattern) {
            let value = Int(match.1) ?? 0
            let unit = match.2.map(String.init) ?? "s"
            guard value > 0 else { return nil }
            switch unit {
            case "second", "seconds", "sec", "s": return value
            case "minute", "minutes", "min", "m": return value * 60
            case "hour", "hours", "hr", "h": return value * 3600
            case "day", "days", "d": return value * 86_400
            default: return value
            }
        }
        if let plain = Int(lower), plain > 0 {
            return plain
        }
        return nil
    }

    private static func parseAbsoluteDate(_ expression: String) -> Date? {
        guard !expression.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: expression) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: expression) { return date }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        for format in [
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy/MM/dd HH:mm",
            "yyyy/MM/dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd"
        ] {
            formatter.dateFormat = format
            if let date = formatter.date(from: expression) { return date }
        }
        return nil
    }

    private static func nextDaily(_ expression: String, after: Date) -> Date? {
        guard let time = parseDailyTime(expression.isEmpty ? "09:00" : expression) else { return nil }
        var calendar = Calendar.current
        calendar.timeZone = .current
        var components = calendar.dateComponents([.year, .month, .day], from: after)
        components.hour = time.hour
        components.minute = time.minute
        components.second = 0
        guard var candidate = calendar.date(from: components) else { return nil }
        if candidate <= after {
            candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }
        return candidate
    }

    private static func nextWeekly(_ expression: String, after: Date) -> Date? {
        guard let weekly = parseWeekly(expression.isEmpty ? "Mon 09:00" : expression) else { return nil }
        var calendar = Calendar.current
        calendar.timeZone = .current
        // Calendar weekday: 1=Sunday ... 6=Saturday matches launchd if we use same.
        for offset in 0..<8 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: after) else { continue }
            let weekday = calendar.component(.weekday, from: day) - 1 // 0=Sunday
            guard weekday == weekly.weekday else { continue }
            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = weekly.hour
            components.minute = weekly.minute
            components.second = 0
            guard let candidate = calendar.date(from: components), candidate > after else { continue }
            return candidate
        }
        return nil
    }

    private static func nextFromCron(_ expression: String, after: Date) -> Date? {
        // Best-effort: "m h * * *" daily, "m h * * d" weekly (0-6)
        let parts = expression.split(whereSeparator: \.isWhitespace)
        guard parts.count >= 5,
              let minute = Int(parts[0]),
              let hour = Int(parts[1]) else {
            return nextDaily("09:00", after: after)
        }
        let dow = String(parts[4])
        if dow == "*" {
            return nextDaily(String(format: "%02d:%02d", hour, minute), after: after)
        }
        if let day = Int(dow) {
            return nextWeekly("\(day) \(String(format: "%02d:%02d", hour, minute))", after: after)
        }
        return nextDaily(String(format: "%02d:%02d", hour, minute), after: after)
    }
}
