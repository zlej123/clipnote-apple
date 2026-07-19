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

/// 뷰 인스턴스가 재생성돼도 유지되는 진행 중 내보내기 추적 — 재진입 중복 방지 (최종 리뷰 반영).
/// 백그라운드 완주는 보존한다(취소하지 않음): 뒤로가기 후에도 페이지는 만들어지고, 재탭만 막는다.
@MainActor
enum NotionExportTracker {
    private(set) static var inFlight: Set<String> = []

    /// 시작 시도 — 이미 진행 중이면 false
    static func begin(_ documentID: String) -> Bool {
        guard !inFlight.contains(documentID) else { return false }
        inFlight.insert(documentID)
        return true
    }

    static func end(_ documentID: String) {
        inFlight.remove(documentID)
    }
}
