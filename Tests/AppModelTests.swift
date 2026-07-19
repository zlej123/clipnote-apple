import Testing
import Foundation
@testable import clipnote

@Suite(.serialized)
@MainActor
struct AppModelTests {
    private func makeModel(root: URL, linkMode: Bool = false) -> AppModel {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: config)
        let keychain = KeychainStore(service: "clipnote.tests.appmodel-\(UUID().uuidString)")
        try? keychain.save("test-key")
        let defaults = UserDefaults(suiteName: "clipnote.tests.appmodel")!
        defaults.removePersistentDomain(forName: "clipnote.tests.appmodel")
        Settings.registerDefaults(defaults)
        defaults.set(linkMode, forKey: Settings.linkModeKey)
        return AppModel(
            keychain: keychain,
            documentStore: DocumentStore(root: root),
            defaults: defaults,
            makeAPI: { ClipnoteAPI(baseURL: $0, session: session) })
    }

    @Test func detectsRecipeProfileFromTitle() {
        #expect(AppModel.detectProfile(title: "돼지고기 김치볶음 레시피 - YouTube") == "recipe")
        #expect(AppModel.detectProfile(title: "Easy pasta cooking guide") == "recipe")
        #expect(AppModel.detectProfile(title: "요리 초보 탈출") == "recipe")
        #expect(AppModel.detectProfile(title: "선반 조립 하우투") == "generic")
    }

    @Test func performAnalysisLinkModeSavesDocument() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("clipnote-appmodel-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        // linkMode: true — Task 11이 캡처 분기를 추가해도 이 테스트는 링크 경로를 검증한다
        let model = makeModel(root: root, linkMode: true)
        let fixture = try Bundle.fixtureData("analyze-response")
        StubURLProtocol.handler = { _ in (200, fixture) }
        defer { StubURLProtocol.handler = nil }

        await model.performAnalysis(videoId: "dQw4w9WgXcQ", duration: 90)

        guard case .done(let meta) = model.stage else {
            Issue.record("stage=\(model.stage)"); return
        }
        let doc = model.document(id: meta.id)
        #expect(doc != nil)
        #expect(doc!.markdown.contains("▶ [영상 0:30에서 직접 확인](https://youtu.be/dQw4w9WgXcQ?t=30)"))
        #expect(doc!.picks.isEmpty)                    // 링크 모드: 픽 없음
        #expect(model.documents().count == 1)
    }

    @Test func performAnalysisMapsErrorToFailedStage() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("clipnote-appmodel-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let model = makeModel(root: root)
        StubURLProtocol.handler = { _ in (429, Data(#"{"detail": "quota"}"#.utf8)) }
        defer { StubURLProtocol.handler = nil }

        await model.performAnalysis(videoId: "dQw4w9WgXcQ", duration: 90)

        guard case .failed(let message) = model.stage else {
            Issue.record("stage=\(model.stage)"); return
        }
        #expect(message.contains("한도"))
    }

    @Test func startRejectsInvalidURLWithoutTouchingPlayer() async {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("clipnote-appmodel-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let model = makeModel(root: root)
        await model.start(urlString: "https://example.com/not-youtube")
        guard case .failed(let message) = model.stage else {
            Issue.record("stage=\(model.stage)"); return
        }
        #expect(message.contains("유튜브"))
    }

    @Test func startInvalidatesInFlightFlowState() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("clipnote-appmodel-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let model = makeModel(root: root)
        let fixture = try Bundle.fixtureData("analyze-response")
        let envelope = try JSONDecoder().decode(AnalyzeEnvelope.self, from: fixture)
        model.pendingResult = AnalyzeResult(videoId: envelope.videoId,
                                            analysis: envelope.analysis, rawAnalysis: fixture)
        model.captures = [GuideCapture(guide: envelope.analysis.visualGuides[0], candidates: [])]

        await model.start(urlString: "not-a-youtube-url")   // 유효성 실패해도 무효화는 선행돼야 한다

        #expect(model.captures.isEmpty)
        #expect(model.pendingResult == nil)
    }
}
