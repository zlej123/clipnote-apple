import Foundation

struct DocumentMeta: Codable, Sendable, Equatable, Identifiable {
    var id: String        // 폴더명: <videoId>-<yyyyMMdd-HHmmss>[-n]
    var title: String
    var videoId: String
    var profile: String
    var language: String
    var createdAt: Date
}

struct SavedDocument: Sendable {
    var meta: DocumentMeta
    var analysis: Analysis
    var picks: [String: String]
    var markdown: String
    var folder: URL
}

/// 스펙 4.6: Documents/clipnote/<id>/ 아래 document.md + vg-N.jpg + meta.json + analysis.json + picks.json
final class DocumentStore: Sendable {
    private let root: URL

    init(root: URL) { self.root = root }

    static func defaultRoot() throws -> URL {
        try FileManager.default.url(for: .documentDirectory, in: .userDomainMask,
                                    appropriateFor: nil, create: true)
            .appendingPathComponent("clipnote", isDirectory: true)
    }

    func folderURL(id: String) -> URL { root.appendingPathComponent(id, isDirectory: true) }

    func save(videoId: String, title: String, analysis: Analysis, rawAnalysis: Data,
              picks: [String: String], images: [String: Data], markdown: String) throws -> DocumentMeta {
        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let base = "\(videoId)-\(formatter.string(from: now))"
        var id = base
        var counter = 2
        while FileManager.default.fileExists(atPath: folderURL(id: id).path) {
            id = "\(base)-\(counter)"
            counter += 1
        }
        let folder = folderURL(id: id)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let meta = DocumentMeta(id: id, title: title, videoId: videoId,
                                profile: analysis.profile ?? "generic",
                                language: analysis.outputLanguage ?? "ko", createdAt: now)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        try Data(markdown.utf8).write(to: folder.appendingPathComponent("document.md"))
        try encoder.encode(meta).write(to: folder.appendingPathComponent("meta.json"))
        try rawAnalysis.write(to: folder.appendingPathComponent("analysis.json"))
        try encoder.encode(picks).write(to: folder.appendingPathComponent("picks.json"))
        for (name, data) in images {
            try data.write(to: folder.appendingPathComponent(name))
        }
        return meta
    }

    func list() throws -> [DocumentMeta] {
        guard FileManager.default.fileExists(atPath: root.path) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let folders = try FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        return folders.compactMap { folder -> DocumentMeta? in
            guard let data = try? Data(contentsOf: folder.appendingPathComponent("meta.json")),
                  let meta = try? decoder.decode(DocumentMeta.self, from: data) else { return nil }
            return meta
        }
        .sorted { ($0.createdAt, $0.id) > ($1.createdAt, $1.id) }
    }

    func load(id: String) throws -> SavedDocument {
        let folder = folderURL(id: id)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let meta = try decoder.decode(
            DocumentMeta.self, from: Data(contentsOf: folder.appendingPathComponent("meta.json")))
        let analysis = try JSONDecoder().decode(
            Analysis.self, from: Data(contentsOf: folder.appendingPathComponent("analysis.json")))
        let picks = try JSONDecoder().decode(
            [String: String].self, from: Data(contentsOf: folder.appendingPathComponent("picks.json")))
        let markdown = try String(
            contentsOf: folder.appendingPathComponent("document.md"), encoding: .utf8)
        return SavedDocument(meta: meta, analysis: analysis, picks: picks,
                             markdown: markdown, folder: folder)
    }

    func delete(id: String) throws {
        try FileManager.default.removeItem(at: folderURL(id: id))
    }
}
