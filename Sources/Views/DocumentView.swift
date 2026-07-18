import SwiftUI

struct DocumentView: View {
    let document: SavedDocument
    @State private var pickingFolder = false
    @State private var exportMessage: String?

    private var analysis: Analysis { document.analysis }
    private var isRecipe: Bool { document.meta.profile == "recipe" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("\(isRecipe ? "🍳" : "📋") \(analysis.title)").font(.title2.bold())
                Text(analysis.summary).foregroundStyle(.secondary)
                if !isRecipe, let category = analysis.category, !category.isEmpty {
                    Text("**분류:** \(category)")
                }
                Text(isRecipe
                     ? "■ 준비 재료\(analysis.servings.map { " (\($0))" } ?? "")"
                     : "■ 준비물").font(.headline)
                ForEach(analysis.materials, id: \.name) { material in
                    Text("• \(material.name) \(material.amount)")
                }
                Text(isRecipe ? "■ 조리 순서" : "■ 순서").font(.headline)
                ForEach(analysis.steps, id: \.id) { step in
                    stepSection(step)
                }
                Divider()
                Link("출처: \(analysis.title) — clipnote로 생성",
                     destination: URL(string: "https://youtu.be/\(document.meta.videoId)")!)
                    .font(.footnote)
                if let exportMessage {
                    Text(exportMessage).font(.caption).foregroundStyle(.orange)
                }
            }
            .padding()
        }
        .navigationTitle(analysis.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                ShareLink(items: shareItems) { Label("공유", systemImage: "square.and.arrow.up") }
                Button { pickingFolder = true } label: {
                    Label("폴더로 저장", systemImage: "folder")
                }
            }
        }
        .fileImporter(isPresented: $pickingFolder, allowedContentTypes: [.folder]) { result in
            if case .success(let directory) = result {
                exportMessage = ExportHelper.copyFolder(
                    from: document.folder, to: directory, name: document.meta.id)
                    ?? "저장 완료: \(directory.lastPathComponent)/\(document.meta.id)"
            }
        }
    }

    @ViewBuilder private func stepSection(_ step: Step) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(step.id). \(step.summary)").font(.body.bold())
            Text(step.detail)
            ForEach(analysis.visualGuides.filter { $0.stepId == step.id }, id: \.id) { guide in
                guideRow(guide)
            }
        }
        .padding(.bottom, 4)
    }

    @ViewBuilder private func guideRow(_ guide: VisualGuide) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("💡 *'\(guide.phrase)' 기준:* \(guide.guideText)")
                .font(.callout)
            let imageURL = document.folder.appendingPathComponent("\(guide.id).jpg")
            if let pick = document.picks[guide.id], pick != "none",
               FileManager.default.fileExists(atPath: imageURL.path) {
                LocalImage(url: imageURL).frame(maxHeight: 240)
            } else {
                // md(코어 패리티)와 정렬: timestamp가 없어도 영상 링크는 항상 제공한다 (리뷰 반영)
                let ts = guide.bestVisualTimestamp
                Link(ts.map { "▶ 영상 \(MarkdownBuilder.hms($0))에서 직접 확인" } ?? "▶ 영상에서 직접 확인",
                     destination: URL(string: ts.map { "https://youtu.be/\(document.meta.videoId)?t=\($0)" }
                                      ?? "https://youtu.be/\(document.meta.videoId)")!)
                    .font(.callout)
            }
        }
        .padding(.leading, 12)
    }

    private var shareItems: [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: document.folder, includingPropertiesForKeys: nil)) ?? []
        let md = files.filter { $0.pathExtension == "md" }
        let jpgs = files.filter { $0.pathExtension == "jpg" }.sorted { $0.path < $1.path }
        return md + jpgs
    }
}
