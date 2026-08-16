import Foundation

enum TemplateEngine {
    static func render(_ template: String, values: [String: String]) -> String {
        var result = template
        for (key, value) in values {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return result
    }

    static func baseValues(
        taskName: String,
        workingDirectory: String,
        date: Date = .now
    ) -> [String: String] {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.dateFormat = "HH:mm:ss"

        return [
            "date": dateFormatter.string(from: date),
            "time": timeFormatter.string(from: date),
            "task_name": taskName,
            "working_directory": workingDirectory
        ]
    }

    static func runValues(
        taskName: String,
        workingDirectory: String,
        status: RunStatus,
        exitCode: Int?,
        duration: TimeInterval?,
        stdout: String,
        date: Date = .now
    ) -> [String: String] {
        var values = baseValues(taskName: taskName, workingDirectory: workingDirectory, date: date)
        values["status"] = status.displayName
        values["exit_code"] = exitCode.map(String.init) ?? ""
        values["duration"] = duration.map { String(format: "%.1f" , $0) } ?? ""
        // Keep notification payloads bounded.
        let clipped = stdout.count > 500 ? String(stdout.prefix(500)) + "…" : stdout
        values["stdout"] = clipped
        return values
    }
}
