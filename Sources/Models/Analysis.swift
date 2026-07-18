import Foundation

struct Material: Codable, Sendable, Equatable {
    var name: String
    var amount: String
}

struct Step: Codable, Sendable, Equatable {
    var id: Int
    var summary: String
    var detail: String
    var tStart: Int
    var tEnd: Int

    enum CodingKeys: String, CodingKey {
        case id, summary, detail
        case tStart = "t_start"
        case tEnd = "t_end"
    }
}

struct VisualGuide: Codable, Sendable, Equatable {
    var id: String
    var stepId: Int
    var sourcePhrase: String
    var phrase: String
    var type: String
    var whatToShow: String
    var bestVisualTimestamp: Int?
    var guideText: String
    var importance: Double

    enum CodingKeys: String, CodingKey {
        case id, phrase, type, importance
        case stepId = "step_id"
        case sourcePhrase = "source_phrase"
        case whatToShow = "what_to_show"
        case bestVisualTimestamp = "best_visual_timestamp"
        case guideText = "guide_text"
    }
}

struct Analysis: Codable, Sendable, Equatable {
    var title: String
    var summary: String
    var category: String?
    var servings: String?
    var materials: [Material]
    var steps: [Step]
    var visualGuides: [VisualGuide]
    var duration: Int?
    var profile: String?
    var outputLanguage: String?

    enum CodingKeys: String, CodingKey {
        case title, summary, category, servings, materials, steps
        case visualGuides = "visual_guides"
        case duration = "_duration"
        case profile = "_profile"
        case outputLanguage = "_output_language"
    }

    /// step_id → Step (캡처·렌더에서 공용)
    var stepsByID: [Int: Step] { Dictionary(uniqueKeysWithValues: steps.map { ($0.id, $0) }) }
}

/// /v1/analyze 응답 envelope
struct AnalyzeEnvelope: Codable, Sendable {
    var videoId: String
    var analysis: Analysis
    var warnings: [String]?

    enum CodingKeys: String, CodingKey {
        case videoId = "video_id"
        case analysis, warnings
    }
}
