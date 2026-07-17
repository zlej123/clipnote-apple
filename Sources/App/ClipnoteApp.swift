import SwiftUI

@main
struct ClipnoteApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.environment["CLIPNOTE_SPIKE"] == "1" {
                SpikeCaptureView()
            } else {
                ContentView()
            }
            #else
            ContentView()
            #endif
        }
    }
}
