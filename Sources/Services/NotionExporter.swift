import Foundation

/// SavedDocument → Notion 페이지 (스펙 3.3).
/// 절차: 픽 이미지 전부 업로드(실패 시 페이지 생성 전 중단) → 블록 → 페이지 생성 → 100블록 배칭.
final class NotionExporter: Sendable {
    private let api: NotionAPI
    private let parentPageID: String

    init(api: NotionAPI, parentPageID: String) {
        self.api = api
        self.parentPageID = parentPageID
    }

    func export(document: SavedDocument) async throws -> URL {
        var uploadIds: [String: String] = [:]
        for guide in document.analysis.visualGuides {
            guard (document.picks[guide.id] ?? "none") != "none" else { continue }
            let file = document.folder.appendingPathComponent("\(guide.id).jpg")
            guard let data = try? Data(contentsOf: file) else { continue }   // 픽은 있는데 파일 없음 → 링크 폴백
            let uploadId = try await api.createFileUpload()
            try await api.sendFileUpload(id: uploadId, data: data, filename: "\(guide.id).jpg")
            uploadIds[guide.id] = uploadId
        }

        let blocks = NotionBlockBuilder.blocks(
            analysis: document.analysis, videoId: document.meta.videoId,
            imageUploadIds: uploadIds)
        let page = try await api.createPage(
            parentPageID: parentPageID, title: document.analysis.title,
            children: Array(blocks.prefix(100)))
        var start = 100
        while start < blocks.count {
            try await api.appendChildren(
                pageID: page.id, blocks: Array(blocks[start..<min(start + 100, blocks.count)]))
            start += 100
        }

        if let urlString = page.url, let url = URL(string: urlString) { return url }
        return URL(string: "https://www.notion.so/"
                   + page.id.replacingOccurrences(of: "-", with: ""))!
    }
}
