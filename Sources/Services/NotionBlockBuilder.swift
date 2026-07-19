import Foundation

/// Notion 블록 표현 — JSONSerialization 호환 딕셔너리.
/// nonisolated 동일 태스크 안에서만 흐른다(MainActor 경계 통과 금지 — 스펙 3.1).
typealias NotionBlock = [String: Any]

/// 코어 export.py::build_notion_blocks(244~288행) 1:1 포팅.
/// 골든(expected-notion.json)이 파리티 심판 — 동작을 임의로 개선하지 말 것.
enum NotionBlockBuilder {
    /// 코어 _rich: 2000자 절단 + 선택적 링크
    static func rich(_ text: String, link: String? = nil) -> [[String: Any]] {
        var textDict: [String: Any] = ["content": String(text.prefix(2000))]
        if let link {
            textDict["link"] = ["url": link]
        }
        return [["type": "text", "text": textDict]]
    }

    static func blocks(analysis: Analysis, videoId: String,
                       imageUploadIds: [String: String]) -> [NotionBlock] {
        var blocks: [NotionBlock] = []
        if !analysis.summary.isEmpty {
            blocks.append(["type": "paragraph",
                           "paragraph": ["rich_text": rich(analysis.summary)]])
        }
        blocks.append(["type": "paragraph", "paragraph": ["rich_text": rich(
            "YouTube 원본", link: "https://youtu.be/\(videoId)")]])

        if !analysis.materials.isEmpty {
            blocks.append(["type": "heading_2",
                           "heading_2": ["rich_text": rich("준비물")]])
            for material in analysis.materials {
                blocks.append(["type": "bulleted_list_item", "bulleted_list_item":
                    ["rich_text": rich("\(material.name) \(material.amount)")]])
            }
        }

        var byStep: [Int: [VisualGuide]] = [:]
        for guide in analysis.visualGuides {
            byStep[guide.stepId, default: []].append(guide)
        }

        blocks.append(["type": "heading_2", "heading_2": ["rich_text": rich("순서")]])
        for step in analysis.steps {
            blocks.append(["type": "numbered_list_item", "numbered_list_item":
                ["rich_text": rich("\(step.summary) — \(step.detail)")]])
            for guide in byStep[step.id] ?? [] {
                blocks.append(["type": "quote", "quote": ["rich_text": rich(
                    "💡 '\(guide.phrase)' 기준: \(guide.guideText)")]])
                if let uploadId = imageUploadIds[guide.id] {
                    blocks.append(["type": "image", "image":
                        ["type": "file_upload", "file_upload": ["id": uploadId]]])
                } else if let ts = guide.bestVisualTimestamp {
                    blocks.append(["type": "paragraph", "paragraph": ["rich_text": rich(
                        "▶ 영상 \(MarkdownBuilder.hms(ts))에서 직접 확인",
                        link: "https://youtu.be/\(videoId)?t=\(ts)")]])
                }
            }
        }
        return blocks
    }
}
