import Foundation

/// 직접 Gemini 모드의 정규화 — 확장 bg.js normalize와 동일 부분집합(시간 문자열 → 초 Int).
/// 서버 normalize의 보완 로직(source_phrase/importance/type alias)은 미포팅: 구조화 출력
/// 스키마가 필수 필드를 강제하므로 실효가 낮다 (스펙 2.3, 확장과 동일 범위).
enum AnalysisNormalizer {
    /// "M:SS"~"MMM:SS" → 초. 이미 숫자면 그대로, nil/비정상 문자열은 nil.
    static func mmssToSec(_ value: Any?) -> Int? {
        if let number = value as? Int { return number }
        if let number = value as? NSNumber { return number.intValue }
        guard let text = value as? String, !text.isEmpty else { return nil }
        var seconds = 0
        for part in text.split(separator: ":") {
            guard let n = Int(part) else { return nil }
            seconds = seconds * 60 + n
        }
        return seconds
    }

    /// dict 레벨 정규화 + 메타 주입 → 타입 모델과 원본 직렬화를 함께 반환
    static func normalized(rawObject: [String: Any], duration: Int, profile: String,
                           language: String) throws -> (analysis: Analysis, rawAnalysis: Data) {
        var object = rawObject
        if var steps = object["steps"] as? [[String: Any]] {
            for index in steps.indices {
                steps[index]["t_start"] = mmssToSec(steps[index]["t_start"]) ?? 0
                steps[index]["t_end"] = mmssToSec(steps[index]["t_end"]) ?? 0
            }
            object["steps"] = steps
        }
        if var guides = object["visual_guides"] as? [[String: Any]] {
            for index in guides.indices {
                guides[index]["best_visual_timestamp"] =
                    mmssToSec(guides[index]["best_visual_timestamp"]) ?? NSNull()
            }
            object["visual_guides"] = guides
        }
        object["_duration"] = duration
        object["_profile"] = profile
        object["_output_language"] = language
        let raw = try JSONSerialization.data(withJSONObject: object)
        let analysis = try JSONDecoder().decode(Analysis.self, from: raw)
        return (analysis, raw)
    }
}
