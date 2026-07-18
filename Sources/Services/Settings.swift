import Foundation

/// @AppStorage 키와 기본값의 단일 원천. 뷰는 @AppStorage(Settings.xxxKey), 로직은 UserDefaults로 읽는다.
enum Settings {
    static let serverURLKey = "serverURL"
    static let languageKey = "language"
    static let linkModeKey = "linkMode"

    static let defaultServerURL = "http://127.0.0.1:8787"
    static let defaultLanguage = "ko"
    static let maxGuides = 5   // v1 고정 (스펙 4.3)

    static func registerDefaults(_ defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            serverURLKey: defaultServerURL,
            languageKey: defaultLanguage,
            linkModeKey: false,
        ])
    }
}
