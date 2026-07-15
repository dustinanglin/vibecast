import Foundation

/// Global download preferences. UserDefaults-backed static accessors with an
/// injectable defaults instance for tests — same pattern as
/// `VibecastApp.splashMode(defaults:)`.
///
/// `true`-defaulting Bools and the Int must use `object(forKey:) == nil` to
/// distinguish "never set" from "set to false/0".
enum DownloadSettings {
    static let autoEnabledKey = "downloadAutoEnabled"
    static let keepLastNKey = "downloadKeepLastN"
    static let deleteWhenPlayedKey = "downloadDeleteWhenPlayed"
    static let wifiOnlyKey = "downloadWifiOnly"

    static func autoDownloadEnabled(defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: autoEnabledKey) as? Bool ?? true
    }

    /// How many auto-downloaded episodes to keep per show. 0 = unlimited.
    static func keepLastN(defaults: UserDefaults = .standard) -> Int {
        defaults.object(forKey: keepLastNKey) as? Int ?? 3
    }

    static func deleteWhenPlayed(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: deleteWhenPlayedKey)
    }

    static func wifiOnly(defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: wifiOnlyKey) as? Bool ?? true
    }

    static func setAutoDownloadEnabled(_ value: Bool, defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: autoEnabledKey)
    }

    static func setKeepLastN(_ value: Int, defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: keepLastNKey)
    }

    static func setDeleteWhenPlayed(_ value: Bool, defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: deleteWhenPlayedKey)
    }

    static func setWifiOnly(_ value: Bool, defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: wifiOnlyKey)
    }
}
