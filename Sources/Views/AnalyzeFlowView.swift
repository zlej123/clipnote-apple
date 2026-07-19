import SwiftUI

struct AnalyzeFlowView: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 14) {
            PlayerWebView(bridge: model.bridge)
                .frame(minHeight: 230)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            stageView
            Spacer()
        }
        .padding()
        .navigationTitle("분석")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("취소") { model.reset(); dismiss() }
            }
        }
    }

    @ViewBuilder private var stageView: some View {
        switch model.stage {
        case .idle:
            Text("대기 중").foregroundStyle(.secondary)
        case .loadingPlayer:
            ProgressView("플레이어 로드 중…")
        case .readyToAnalyze(let duration, let title):
            VStack(spacing: 10) {
                Text(title).font(.callout).lineLimit(2)
                Text("길이 \(MarkdownBuilder.hms(duration))").font(.caption).foregroundStyle(.secondary)
                Picker("프로파일", selection: Binding(
                    get: { model.profileOverride ?? model.detectedProfile },
                    set: { model.profileOverride = $0 })) {
                    Text("일반").tag("generic")
                    Text("요리").tag("recipe")
                }
                .pickerStyle(.segmented)
                Button("분석 시작") { Task { await model.confirmAnalyze() } }
                    .buttonStyle(.borderedProminent)
            }
        case .analyzing(let duration):
            ProgressView("영상 분석 중… (\(MarkdownBuilder.hms(duration)), \(model.profile))")
        case .capturing(let current, let total):
            ProgressView("장면 캡처 중… \(current)/\(total)")
        case .picking:
            CandidatePickerView(model: model)
        case .building:
            ProgressView("문서 생성 중…")
        case .done(let meta):
            VStack(spacing: 10) {
                Label("완료", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                // value 기반 링크는 이 뷰가 isPresented로 푸시된 브랜치라 루트 List의
                // String 목적지 등록을 못 봐서 활성화되지 않는다 → 목적지 직접 지정으로 우회
                if let document = model.document(id: meta.id) {
                    NavigationLink("문서 보기") { DocumentView(document: document) }
                        .buttonStyle(.borderedProminent)
                }
            }
        case .failed(let message):
            VStack(spacing: 10) {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red).font(.callout)
                    .multilineTextAlignment(.center)
                Button("다시 시도") { Task { await model.retry() } }
            }
        }
    }
}
