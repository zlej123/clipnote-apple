import SwiftUI

/// 스펙 5.3: 가이드별 3후보 + "부적합(링크 사용)", center 기본 선택. 자동 선택 없음(사용자 확정 필수).
struct CandidatePickerView: View {
    @Bindable var model: AppModel
    @State private var picks: [String: String] = [:]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("가이드별로 의미가 가장 잘 보이는 장면을 고르세요")
                    .font(.callout).foregroundStyle(.secondary)
                ForEach(model.captures) { capture in
                    guideCard(capture)
                }
                Button("문서 만들기") {
                    Task { await model.finishPicking(picks: picks) }
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical)
        }
        .onAppear { if picks.isEmpty { picks = model.defaultPicks() } }
    }

    @ViewBuilder private func guideCard(_ capture: GuideCapture) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(capture.guide.id) · \(capture.guide.phrase)").font(.headline)
            Text(capture.guide.guideText).font(.caption).foregroundStyle(.secondary)
            if capture.failed {
                Label("캡처 실패 — 링크로 대체됩니다", systemImage: "link")
                    .font(.callout).foregroundStyle(.orange)
            } else {
                HStack(spacing: 8) {
                    ForEach(capture.candidates, id: \.slot) { candidate in
                        candidateCell(guideId: capture.guide.id, candidate: candidate)
                    }
                    noneCell(guideId: capture.guide.id)
                }
            }
        }
    }

    @ViewBuilder private func candidateCell(guideId: String, candidate: CaptureCandidate) -> some View {
        if let jpeg = candidate.jpeg {
            Button {
                picks[guideId] = candidate.slot
            } label: {
                VStack(spacing: 4) {
                    JPEGImage(data: jpeg)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(
                            picks[guideId] == candidate.slot ? Color.red : Color.secondary.opacity(0.3),
                            lineWidth: picks[guideId] == candidate.slot ? 3 : 1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    Text("\(MarkdownBuilder.hms(candidate.time)) (\(candidate.slot))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func noneCell(guideId: String) -> some View {
        Button {
            picks[guideId] = "none"
        } label: {
            VStack {
                Text("부적합\n링크 사용").font(.caption).multilineTextAlignment(.center)
            }
            .frame(minWidth: 64, minHeight: 48)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(
                picks[guideId] == "none" ? Color.red : Color.secondary.opacity(0.3),
                lineWidth: picks[guideId] == "none" ? 3 : 1))
        }
        .buttonStyle(.plain)
    }
}
