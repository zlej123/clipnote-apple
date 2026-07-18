import Foundation

enum YouTubeURL {
    /// 코어 common.py 정규식 + 강화 2가지(11자 뒤경계, 유튜브 도메인 확인).
    /// 리터럴은 컴파일 타임에 구워지므로 호출마다 재컴파일 비용은 없다.
    static func videoID(from string: String) -> String? {
        guard string.contains("youtube.com") || string.contains("youtu.be") else { return nil }
        guard let match = string.firstMatch(
            of: /(?:v=|youtu\.be\/|shorts\/)([\w-]{11})(?![\w-])/) else { return nil }
        return String(match.1)
    }

    static func watchURL(videoID: String) -> URL {
        URL(string: "https://m.youtube.com/watch?v=\(videoID)")!
    }
}
