import Foundation

/// 노션 페이지 식별자 정규화 — 페이지 URL·하이픈 UUID·32자 hex 입력을 모두 허용하고
/// 하이픈 없는 32자 소문자 hex로 통일한다 (설정 입력 편의: 페이지 URL을 그대로 붙여넣어도 됨).
enum NotionPageID {
    static func normalize(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let match = trimmed.firstMatch(
            of: /[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}|[0-9a-fA-F]{32}(?![0-9a-fA-F])/)
        else { return nil }
        return String(match.output)
            .replacingOccurrences(of: "-", with: "")
            .lowercased()
    }
}
