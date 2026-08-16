import Foundation

struct LaunchdJob: Codable, Equatable {
    var label: String
    var programArguments: [String]
    var workingDirectory: String?
    var startInterval: Int?
    var calendarYear: Int?
    var calendarMonth: Int?
    var calendarDay: Int?
    var calendarHour: Int?
    var calendarMinute: Int?
    var calendarWeekday: Int?
    var runAtLoad: Bool
    var disabled: Bool

    static func label(for taskID: UUID) -> String {
        "com.runly.task.\(taskID.uuidString)"
    }

    func plistDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "Label": label,
            "ProgramArguments": programArguments,
            "RunAtLoad": runAtLoad,
            "Disabled": disabled,
            "StandardOutPath": AppPaths.applicationSupport
                .appendingPathComponent("launchd-\(label).out.log").path,
            "StandardErrorPath": AppPaths.applicationSupport
                .appendingPathComponent("launchd-\(label).err.log").path
        ]
        if let workingDirectory, !workingDirectory.isEmpty {
            dict["WorkingDirectory"] = workingDirectory
        }
        if let startInterval {
            dict["StartInterval"] = startInterval
        }
        var calendar: [String: Int] = [:]
        if let calendarYear { calendar["Year"] = calendarYear }
        if let calendarMonth { calendar["Month"] = calendarMonth }
        if let calendarDay { calendar["Day"] = calendarDay }
        if let calendarHour { calendar["Hour"] = calendarHour }
        if let calendarMinute { calendar["Minute"] = calendarMinute }
        if let calendarWeekday { calendar["Weekday"] = calendarWeekday }
        if !calendar.isEmpty {
            dict["StartCalendarInterval"] = calendar
        }
        return dict
    }

    func writePlist(to url: URL) throws {
        let data = try PropertyListSerialization.data(
            fromPropertyList: plistDictionary(),
            format: .xml,
            options: 0
        )
        try data.write(to: url, options: .atomic)
    }
}
