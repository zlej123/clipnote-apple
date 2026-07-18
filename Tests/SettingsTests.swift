import Testing
import Foundation
@testable import clipnote

struct SettingsTests {
    @Test func registersDefaults() {
        let suite = UserDefaults(suiteName: "clipnote.tests.settings")!
        suite.removePersistentDomain(forName: "clipnote.tests.settings")
        Settings.registerDefaults(suite)
        #expect(suite.string(forKey: Settings.serverURLKey) == "http://127.0.0.1:8787")
        #expect(suite.string(forKey: Settings.languageKey) == "ko")
        #expect(suite.bool(forKey: Settings.linkModeKey) == false)
    }
}
