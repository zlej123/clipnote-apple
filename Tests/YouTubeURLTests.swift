import Testing
@testable import clipnote

struct YouTubeURLTests {
    @Test func parsesCommonForms() {
        #expect(YouTubeURL.videoID(from: "https://www.youtube.com/watch?v=4ioPBiTWm3M") == "4ioPBiTWm3M")
        #expect(YouTubeURL.videoID(from: "https://m.youtube.com/watch?v=4ioPBiTWm3M&t=10") == "4ioPBiTWm3M")
        #expect(YouTubeURL.videoID(from: "https://youtu.be/4ioPBiTWm3M?si=abc") == "4ioPBiTWm3M")
        #expect(YouTubeURL.videoID(from: "https://www.youtube.com/shorts/4ioPBiTWm3M") == "4ioPBiTWm3M")
    }
    @Test func rejectsInvalid() {
        #expect(YouTubeURL.videoID(from: "https://example.com/watch?v=abc") == nil)
        #expect(YouTubeURL.videoID(from: "그냥 텍스트") == nil)
        #expect(YouTubeURL.videoID(from: "https://www.youtube.com/watch?v=short") == nil)
    }
}
