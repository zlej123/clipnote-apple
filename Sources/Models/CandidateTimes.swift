/// capture.py::candidate_times 포팅 — 후보 3장을 스텝 범위에 걸쳐 분산
struct CandidateTimes: Equatable, Sendable {
    let before: Int
    let center: Int
    let after: Int

    init(step: Step?, center: Int, duration: Int) {
        self.center = center
        let last = max(0, duration - 1)
        if let step {
            before = max(0, step.tStart - 1)
            after = min(last, step.tEnd + 1)
        } else {
            before = max(0, center - 4)
            after = min(last, center + 4)
        }
    }

    var slots: [(slot: String, time: Int)] {
        [("before", before), ("center", center), ("after", after)]
    }
}
