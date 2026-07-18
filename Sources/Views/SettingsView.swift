import SwiftUI

struct SettingsView: View {
    @AppStorage(Settings.serverURLKey) private var serverURL = Settings.defaultServerURL
    @AppStorage(Settings.languageKey) private var language = Settings.defaultLanguage
    @AppStorage(Settings.linkModeKey) private var linkMode = false
    @State private var geminiKey = ""
    @State private var keySavedAt: Date?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("AI Studio에서 발급한 키", text: $geminiKey)
                        .textFieldStyle(.roundedBorder)
                    Button("키 저장") {
                        try? KeychainStore.geminiKey.save(
                            geminiKey.trimmingCharacters(in: .whitespacesAndNewlines))
                        keySavedAt = Date()
                    }
                    .disabled(geminiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if keySavedAt != nil {
                        Label("저장됨", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green).font(.callout)
                    }
                    Link("AI Studio에서 무료 키 발급 (카드 불필요)",
                         destination: URL(string: "https://aistudio.google.com/apikey")!)
                        .font(.callout)
                } header: { Text("Gemini API 키") } footer: {
                    Text("키는 이 기기의 Keychain에만 저장되고 분석 요청에만 사용됩니다.")
                }
                Section("분석") {
                    Picker("문서 언어", selection: $language) {
                        Text("한국어").tag("ko")
                        Text("English").tag("en")
                        Text("日本語").tag("ja")
                    }
                    Toggle("링크 모드", isOn: $linkMode)
                    Text("링크 모드: 화면 캡처 없이 모든 가이드를 유튜브 타임스탬프 링크로 넣습니다.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    TextField("서버 URL", text: $serverURL)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                } header: { Text("clipnote 서버") } footer: {
                    Text("실기기에서는 Mac의 LAN IP를 입력하세요 (예: http://192.168.0.10:8787)")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("설정")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("닫기") { dismiss() } } }
            .onAppear { geminiKey = (try? KeychainStore.geminiKey.load()) ?? "" }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 420)
        #endif
    }
}
