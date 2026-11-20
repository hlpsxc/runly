import Foundation

// Compile in isolation with Runly/Utilities/ScheduleCalculator.swift, without the app/UI.
enum ScheduleType { case once, interval, daily, weekly, weekdays }

@main
struct ScheduleTimeZoneSmoke {
    static func main() {
        func check(_ ok: @autoclosure () -> Bool, _ reason: String) {
            guard ok() else { fputs("FAIL: \(reason)\n", stderr); exit(1) }
        }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        func instant(_ value: String) -> Date { iso.date(from: value)! }
        func next(_ type: ScheduleType, _ expr: String, after: String, zone: String?) -> String {
            let date = ScheduleCalculator.nextRunDate(
                type: type, expression: expr, after: instant(after),
                enabled: true, timeZoneIdentifier: zone)!
            return iso.string(from: date)
        }

        // Missing field is the compatibility contract for old SwiftData rows.
        check(ScheduleCalculator.resolvedTimeZoneIdentifier(nil) == "Asia/Shanghai",
              "nil resolves to legacy Beijing")
        check(ScheduleCalculator.resolvedTimeZoneIdentifier("") == "Asia/Shanghai",
              "empty resolves to legacy Beijing")
        check(ScheduleCalculator.resolvedTimeZoneIdentifier("Not/AZone") == "Asia/Shanghai",
              "invalid identifier falls back visibly to Beijing at runtime")
        check(ScheduleCalculator.isValidTimeZoneIdentifier(nil), "nil is legacy-valid")
        check(ScheduleCalculator.isValidTimeZoneIdentifier("Asia/Tokyo"), "Tokyo is valid")
        check(!ScheduleCalculator.isValidTimeZoneIdentifier("Asia/Bejing"), "typo is invalid")

        check(next(.daily, "09:00", after: "2026-11-20T00:00:00Z", zone: nil)
              == "2026-11-20T01:00:00Z", "legacy Beijing daily")
        check(next(.daily, "09:00", after: "2026-11-20T00:00:00Z", zone: "Asia/Tokyo")
              == "2026-11-21T00:00:00Z", "Tokyo daily")
        check(next(.weekly, "Mon 09:00", after: "2026-11-20T00:00:00Z", zone: "Asia/Tokyo")
              == "2026-11-23T00:00:00Z", "Tokyo weekly")
        check(next(.weekdays, "09:00", after: "2026-11-20T00:00:00Z", zone: "Asia/Tokyo")
              == "2026-11-23T00:00:00Z", "weekdays skip elapsed Friday")
        check(next(.interval, "Every 1 hour", after: "2026-11-20T00:00:00Z", zone: "Asia/Tokyo")
              == "2026-11-20T01:00:00Z", "interval remains absolute seconds")

        // Zone switch keeps wall-clock expression; only the absolute instant moves.
        let tokyoInstant = ScheduleCalculator.nextRunDate(
            type: .daily, expression: "09:00", after: instant("2026-11-20T00:00:00Z"),
            enabled: true, timeZoneIdentifier: "Asia/Shanghai")!
        let shanghaiWall = ScheduleCalculator.formatOnceDate(
            tokyoInstant, timeZoneIdentifier: "Asia/Shanghai")
        check(shanghaiWall.hasSuffix("09:00") || shanghaiWall.contains(" 09:00"),
              "Shanghai wall clock for daily next")
        check(next(.daily, "09:00", after: "2026-11-20T00:00:00Z", zone: "Asia/Tokyo")
              != next(.daily, "09:00", after: "2026-11-20T00:00:00Z", zone: "Asia/Shanghai"),
              "same wall clock yields different instants across zones")

        // New York spring DST gap: nonexistent 02:30 moves to a valid local time.
        let gap = ScheduleCalculator.nextRunDate(
            type: .daily, expression: "02:30",
            after: instant("2027-03-14T06:00:00Z"), enabled: true,
            timeZoneIdentifier: "America/New_York")!
        check(gap > instant("2027-03-14T06:00:00Z"), "DST gap returns future instant")
        let ny = ScheduleCalculator.scheduleCalendar(timeZoneIdentifier: "America/New_York")
        check(ny.component(.day, from: gap) == 14, "DST gap stays on matching day")

        // Fall-back repeated local time: first occurrence policy.
        let fall = ScheduleCalculator.nextRunDate(
            type: .daily, expression: "01:30",
            after: instant("2026-11-01T04:00:00Z"), enabled: true,
            timeZoneIdentifier: "America/New_York")!
        check(fall > instant("2026-11-01T04:00:00Z"), "DST fall-back returns future instant")

        let once = ScheduleCalculator.parseOnceDate("2026-11-20 09:00",
                                                     timeZoneIdentifier: "Asia/Tokyo")
        check(once == instant("2026-11-20T00:00:00Z"), "once date parse in Tokyo")
        check(ScheduleCalculator.formatOnceDate(once!, timeZoneIdentifier: "Asia/Tokyo")
              == "2026-11-20 09:00", "once roundtrip preserves local clock")

        // Switching Once timezone keeps the expression string; absolute next changes.
        let onceTokyo = ScheduleCalculator.nextRunDate(
            type: .once, expression: "2026-11-20 09:00",
            after: instant("2026-11-19T00:00:00Z"), enabled: true,
            timeZoneIdentifier: "Asia/Tokyo")
        let onceShanghai = ScheduleCalculator.nextRunDate(
            type: .once, expression: "2026-11-20 09:00",
            after: instant("2026-11-19T00:00:00Z"), enabled: true,
            timeZoneIdentifier: "Asia/Shanghai")
        check(onceTokyo != onceShanghai, "once wall clock remaps absolute instant on zone change")
        check(ScheduleCalculator.nextRunDate(type: .once, expression: "2026-11-20 09:00",
                  after: instant("2026-11-20T00:00:00Z"), enabled: true,
                  timeZoneIdentifier: "Asia/Tokyo") == nil, "one shot does not rerun at boundary")
        check(ScheduleCalculator.nextRunDate(type: .once, expression: "2026-11-20 09:00",
                  after: instant("2026-11-21T00:00:00Z"), enabled: true,
                  timeZoneIdentifier: "Asia/Tokyo") == nil, "already-fired once stays nil")

        // Cross-week boundary in Tokyo: Fri 09:00 after Friday morning → next Mon for weekdays.
        check(next(.weekdays, "09:00", after: "2026-11-20T01:00:00Z", zone: "Asia/Tokyo")
              == "2026-11-23T00:00:00Z", "weekdays cross weekend boundary")

        check(TimeZone.knownTimeZoneIdentifiers.contains("Pacific/Auckland"),
              "IANA catalog available for picker completeness")

        print("PASS: schedule timezone compatibility, validation, DST and once-shot checks")
    }
}
