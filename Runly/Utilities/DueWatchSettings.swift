import Foundation

/// How often the in-process scheduler checks for due tasks.
enum DueWatchSettings {
    private static let storageKey = "runly.dueWatchIntervalSeconds"
    static let defaultSeconds = 20
    static let minSeconds = 5
    static let maxSeconds = 300

    static var intervalSeconds: Int {
        get {
            if UserDefaults.standard.object(forKey: storageKey) == nil {
                return defaultSeconds
            }
            return clamped(UserDefaults.standard.integer(forKey: storageKey))
        }
        set {
            UserDefaults.standard.set(clamped(newValue), forKey: storageKey)
        }
    }

    static func clamped(_ value: Int) -> Int {
        min(max(value, minSeconds), maxSeconds)
    }
}
