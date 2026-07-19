import SwiftUI

/// 원탭 이상 신고 시트 — submit 클로저가 실제 전송을 수행하고, 실패 메시지(성공 시 nil)를 반환한다.
struct ReportSheet: View {
    let submit: (ReportReason, String) async -> String?
    @State private var reason: ReportReason = .candidates
    @State private var note = ""
    @State private var sending = false
    @State private var errorMessage: String?
    @State private var done = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Picker("사유", selection: $reason) {
                    ForEach(ReportReason.allCases) { reason in
                        Text(reason.label).tag(reason)
                    }
                }
                Section("메모 (선택)") {
                    TextEditor(text: $note).frame(minHeight: 80)
                }
                Section {
                    if done {
                        Label("신고 완료 — 개선에 사용할게요!", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button {
                            sending = true
                            errorMessage = nil
                            Task {
                                errorMessage = await submit(reason, note)
                                sending = false
                                if errorMessage == nil {
                                    done = true
                                    try? await Task.sleep(for: .seconds(1))
                                    dismiss()
                                }
                            }
                        } label: {
                            if sending { ProgressView() } else { Text("보내기") }
                        }
                        .disabled(sending)
                    }
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red).font(.callout)
                    }
                } footer: {
                    Text("영상 주소와 분석 결과, 선택 내역이 내 서버로 전송됩니다.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("이상 신고")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 360)
        #endif
    }
}
