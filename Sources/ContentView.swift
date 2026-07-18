import SwiftUI

struct ContentView: View {
    @State private var model = AppModel()

    var body: some View {
        NavigationStack {
            HomeView(model: model)
        }
        .task {
            #if DEBUG
            if let url = ProcessInfo.processInfo.environment["CLIPNOTE_E2E_URL"] {
                try? KeychainStore.geminiKey.save("e2e-stub-key")
                if ProcessInfo.processInfo.environment["CLIPNOTE_LINK_MODE"] == "1" {
                    UserDefaults.standard.set(true, forKey: Settings.linkModeKey)
                }
                model.autoContinue = true
                await model.start(urlString: url)
            }
            #endif
        }
    }
}

#Preview {
    ContentView()
}
