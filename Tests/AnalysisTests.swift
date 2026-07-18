import Testing
import Foundation
@testable import clipnote

struct AnalysisTests {
    @Test func decodesAnalyzeResponseFixture() throws {
        let data = try Bundle.fixtureData("analyze-response")
        let envelope = try JSONDecoder().decode(AnalyzeEnvelope.self, from: data)
        #expect(envelope.videoId == "dQw4w9WgXcQ")
        let a = envelope.analysis
        #expect(a.title == "테스트 하우투 영상")
        #expect(a.category == "생활")
        #expect(a.servings == nil)
        #expect(a.materials.count == 2)
        #expect(a.steps[0].tStart == 5 && a.steps[1].tEnd == 55)
        #expect(a.visualGuides[0].bestVisualTimestamp == 30)
        #expect(a.visualGuides[1].bestVisualTimestamp == nil)
        #expect(a.visualGuides[0].stepId == 2)
        #expect(a.duration == 90)
        #expect(a.profile == "generic")
    }
}
