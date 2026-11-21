import Foundation

enum ScheduleCalculator {
    // Old database records do not have a zone; nil preserves their original Beijing schedule.
    static let legacyTimeZoneIdentifier = "Asia/Shanghai"

    /// Common picker shortcuts; the editor also offers the full IANA catalog.
    static let commonTimeZoneIdentifiers: [String] = [
        "Asia/Shanghai",
        "Asia/Tokyo",
        "Asia/Singapore",
        "Asia/Hong_Kong",
        "Etc/UTC",
        "Europe/London",
        "Europe/Paris",
        "America/New_York",
        "America/Chicago",
        "America/Los_Angeles",
        "Australia/Sydney"
    ]

    /// True only for known IANA identifiers. Empty / nil is treated as legacy Beijing, not invalid.
    static func isValidTimeZoneIdentifier(_ identifier: String?) -> Bool {
        guard let identifier else { return true }
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        return TimeZone(identifier: trimmed) != nil
    }

    /// Identifier that will actually be used for scheduling (after legacy / invalid fallback).
    static func resolvedTimeZoneIdentifier(_ identifier: String?) -> String {
        let trimmed = identifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            return legacyTimeZoneIdentifier
        }
        if TimeZone(identifier: trimmed) != nil {
            return trimmed
        }
        return legacyTimeZoneIdentifier
    }

    static func timeZone(for identifier: String?) -> TimeZone {
        TimeZone(identifier: resolvedTimeZoneIdentifier(identifier))
            ?? TimeZone(identifier: legacyTimeZoneIdentifier)!
    }

    static func scheduleCalendar(timeZoneIdentifier: String? = nil) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone(for: timeZoneIdentifier)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    /// Preview the next fire without mutating persistence. Nil when disabled or already fired (once).
    static func previewNextRun(
        type: ScheduleType,
        expression: String,
        enabled: Bool,
        timeZoneIdentifier: String?,
        after: Date = .now
    ) -> Date? {
        nextRunDate(
            type: type,
            expression: expression,
            after: after,
            enabled: enabled,
            timeZoneIdentifier: timeZoneIdentifier
        )
    }

    /// What to do after claiming an overdue `nextRunAt` slot.
    ///
    /// Default is `runOnceOnWake`: fire the overdue slot once, then schedule the
    /// next occurrence strictly after `now` (skip backlog catch-up). Interval
    /// schedules still advance by elapsed seconds from `now`.
    enum MissedRunPolicy: String, CaseIterable {
        case runOnceOnWake
    }

    /// Next `nextRunAt` after the due watcher claims `claimedSlot`.
    static func nextRunDateAfterClaim(
        type: ScheduleType,
        expression: String,
        claimedSlot: Date,
        now: Date = .now,
        enabled: Bool,
        timeZoneIdentifier: String? = nil,
        policy: MissedRunPolicy = .runOnceOnWake
    ) -> Date? {
        guard enabled else { return nil }
        let after: Date
        switch policy {
        case .runOnceOnWake:
            // Prefer "now" so a multi-day backlog does not chain one fire per poll tick.
            after = max(claimedSlot, now)
        }
        return nextRunDate(
            type: type,
            expression: expression,
            after: after,
            enabled: enabled,
            timeZoneIdentifier: timeZoneIdentifier
        )
    }

    static func nextRunDate(
        type: ScheduleType,
        expression: String,
        after: Date = .now,
        enabled: Bool,
        timeZoneIdentifier: String? = nil
    ) -> Date? {
        guard enabled else { return nil }
        let expr = expression.trimmingCharacters(in: .whitespacesAndNewlines)

        switch type {
        case .once:
            if let date = parseAbsoluteDate(expr, timeZoneIdentifier: timeZoneIdentifier), date > after {
                return date
            }
            return nil
        case .interval:
            guard let seconds = parseIntervalSeconds(expr) else { return nil }
            return after.addingTimeInterval(TimeInterval(seconds))
        case .daily:
            return nextDaily(expr, after: after, timeZoneIdentifier: timeZoneIdentifier)
        case .weekly:
            return nextWeekly(expr, after: after, timeZoneIdentifier: timeZoneIdentifier)
        case .weekdays:
            return nextWeekdays(expr, after: after, timeZoneIdentifier: timeZoneIdentifier)
        }
    }

    /// Seconds for interval schedules.
    static func intervalSeconds(expression: String) -> Int? {
        parseIntervalSeconds(expression.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static func parseDailyTime(_ expression: String) -> (hour: Int, minute: Int)? {
        let expr = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        // Accept "9:05", "09:05", "09:05:00"; zone provided when evaluating.
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
        // Formats: "Mon 09:00", "1 09:00" (0=Sunday … 6=Saturday)
        let expr = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = expr.split(whereSeparator: \.isWhitespace)
        guard tokens.count >= 2 else { return nil }
        guard let time = parseDailyTime(tokens.dropFirst().joined(separator: " "))
                ?? parseDailyTime(String(tokens[1])) else { return nil }

        let dayToken = tokens[0].lowercased()
        let weekday: Int?
        if let number = Int(dayToken), (0...7).contains(number) {
            // Accept 0/7 = Sunday … 6 = Saturday
            weekday = number == 7 ? 0 : number
        } else {
            weekday = weekdayAbbreviationMap[dayToken]
        }
        guard let weekday else { return nil }
        return (weekday, time.hour, time.minute)
    }

    static func parseOnceDate(_ expression: String, timeZoneIdentifier: String? = nil) -> Date? {
        parseAbsoluteDate(expression.trimmingCharacters(in: .whitespacesAndNewlines),
                          timeZoneIdentifier: timeZoneIdentifier)
    }

    static func formatOnceDate(_ date: Date, timeZoneIdentifier: String? = nil) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone(for: timeZoneIdentifier)
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    static func formatDailyTime(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }

    static func formatWeekly(weekday: Int, hour: Int, minute: Int) -> String {
        let day = weekdayAbbreviations.indices.contains(weekday)
            ? weekdayAbbreviations[weekday]
            : "Mon"
        return "\(day) \(formatDailyTime(hour: hour, minute: minute))"
    }

    static func dateForDailyTime(_ expression: String, reference: Date = .now,
                                 timeZoneIdentifier: String? = nil) -> Date {
        let time = parseDailyTime(expression) ?? (9, 0)
        return date(settingHour: time.hour, minute: time.minute, of: reference,
                    timeZoneIdentifier: timeZoneIdentifier)
    }

    static func date(settingHour hour: Int, minute: Int, of reference: Date = .now,
                     timeZoneIdentifier: String? = nil) -> Date {
        let calendar = scheduleCalendar(timeZoneIdentifier: timeZoneIdentifier)
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: reference) ?? reference
    }

    static func defaultOnceDate(after: Date = .now, timeZoneIdentifier: String? = nil) -> Date {
        let calendar = scheduleCalendar(timeZoneIdentifier: timeZoneIdentifier)
        let nextMinute = calendar.date(byAdding: .minute, value: 1, to: after) ?? after.addingTimeInterval(60)
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: nextMinute)
        return calendar.date(from: comps) ?? nextMinute
    }

    /// Weekday 0…6 → short English label used in expressions.
    static let weekdayAbbreviations = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    /// Convert a legacy 5-field cron string to once/daily/weekly/weekdays.
    static func migrateCronExpression(_ expression: String) -> (type: ScheduleType, expression: String) {
        let parts = expression.split(whereSeparator: \.isWhitespace).map(String.init)
        guard parts.count >= 5,
              let minute = Int(parts[0]),
              let hour = Int(parts[1]) else {
            return (.daily, "09:00")
        }
        let time = formatDailyTime(hour: hour, minute: minute)
        let dow = parts[4]
        if dow == "*" {
            return (.daily, time)
        }
        guard let days = parseCronDayOfWeekField(dow), !days.isEmpty else {
            return (.daily, time)
        }
        if days == Set([1, 2, 3, 4, 5]) {
            return (.weekdays, time)
        }
        if days.count == 1, let day = days.first {
            return (.weekly, formatWeekly(weekday: day, hour: hour, minute: minute))
        }
        return (.daily, time)
    }

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

    private static func parseAbsoluteDate(_ expression: String, timeZoneIdentifier: String?) -> Date? {
        guard !expression.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: expression) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: expression) { return date }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone(for: timeZoneIdentifier)
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

    // DST: gaps advance to the next valid local time; repeats choose first occurrence.
    private static func nextDaily(_ expression: String, after: Date,
                                  timeZoneIdentifier: String?) -> Date? {
        guard let time = parseDailyTime(expression.isEmpty ? "09:00" : expression) else { return nil }
        return scheduleCalendar(timeZoneIdentifier: timeZoneIdentifier).nextDate(
            after: after,
            matching: DateComponents(hour: time.hour, minute: time.minute, second: 0),
            matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward)
    }

    private static func nextWeekly(_ expression: String, after: Date,
                                   timeZoneIdentifier: String?) -> Date? {
        guard let w = parseWeekly(expression.isEmpty ? "Mon 09:00" : expression) else { return nil }
        return nextOnWeekdays(Set([w.weekday]), hour: w.hour, minute: w.minute,
                              after: after, timeZoneIdentifier: timeZoneIdentifier)
    }

    private static func nextOnWeekdays(_ weekdays: Set<Int>, hour: Int, minute: Int,
                                       after: Date, timeZoneIdentifier: String?) -> Date? {
        guard !weekdays.isEmpty else { return nil }
        let calendar = scheduleCalendar(timeZoneIdentifier: timeZoneIdentifier)
        return weekdays.compactMap { weekday -> Date? in
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            components.second = 0
            components.weekday = weekday + 1
            return calendar.nextDate(
                after: after,
                matching: components,
                matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward)
        }.min()
    }

    private static func nextWeekdays(_ expression: String, after: Date,
                                     timeZoneIdentifier: String?) -> Date? {
        let time = parseDailyTime(expression.isEmpty ? "08:00" : expression) ?? (8, 0)
        return nextOnWeekdays(Set([1, 2, 3, 4, 5]), hour: time.hour, minute: time.minute,
                              after: after, timeZoneIdentifier: timeZoneIdentifier)
    }

    /// Parse cron day-of-week field into weekdays (0=Sunday … 6=Saturday).
    /// Supports `1`, `1,3,5`, `1-5`, `0-6`, and `7` as Sunday.
    static func parseCronDayOfWeekField(_ field: String) -> Set<Int>? {
        let trimmed = field.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "*" else { return nil }

        var result = Set<Int>()
        for token in trimmed.split(separator: ",") {
            let piece = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if piece.isEmpty { continue }

            if let rangeSep = piece.firstIndex(of: "-") {
                let startToken = String(piece[..<rangeSep])
                let endToken = String(piece[piece.index(after: rangeSep)...])
                guard let start = cronWeekdayNumber(startToken),
                      let end = cronWeekdayNumber(endToken) else { return nil }
                if start <= end {
                    for value in start...end {
                        result.insert(normalizeCronWeekday(value))
                    }
                } else {
                    // Wrap around e.g. 5-1 — uncommon; treat as invalid.
                    return nil
                }
            } else if let value = cronWeekdayNumber(piece) {
                result.insert(normalizeCronWeekday(value))
            } else {
                return nil
            }
        }
        return result.isEmpty ? nil : result
    }

    private static func cronWeekdayNumber(_ token: String) -> Int? {
        if let number = Int(token), (0...7).contains(number) {
            return number
        }
        return weekdayAbbreviationMap[token]
    }

    private static func normalizeCronWeekday(_ value: Int) -> Int {
        value == 7 ? 0 : value
    }
}
