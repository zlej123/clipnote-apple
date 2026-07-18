import Foundation

enum YouTubeURL {
    // 컴파일러 강제 어댑테이션(Swift 6 strict concurrency): Regex<(Substring, Substring)>가
    // Sendable로 추론되지 않아 static let이 "may have shared mutable state"로 거부됨.
    // 컴파일된 정규식은 초기화 후 불변으로만 읽히므로 nonisolated(unsafe)로 안전하게 공유.
    private nonisolated(unsafe) static let pattern = /(?:v=|youtu\.be\/|shorts\/)([\w-]{11})(?![\w-])/

    static func videoID(from string: String) -> String? {
        guard string.contains("youtube.com") || string.contains("youtu.be") else { return nil }
        guard let match = string.firstMatch(of: pattern) else { return nil }
        return String(match.1)
    }

    static func watchURL(videoID: String) -> URL {
        URL(string: "https://m.youtube.com/watch?v=\(videoID)")!
    }
}
