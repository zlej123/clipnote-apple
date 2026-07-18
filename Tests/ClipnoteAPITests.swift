import Testing
import Foundation
@testable import clipnote

final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (Int, Data))?
    nonisolated(unsafe) static var networkError: (any Error)?
    nonisolated(unsafe) static var capturedRequest: URLRequest?
    nonisolated(unsafe) static var capturedBody: Data?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        if let error = Self.networkError {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        Self.capturedRequest = request
        Self.capturedBody = request.bodyData
        let (status, data) = Self.handler!(request)
        let response = HTTPURLResponse(
            url: request.url!, statusCode: status, httpVersion: nil,
            headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

extension URLRequest {
    /// URLSession이 body를 스트림으로 넘길 때가 있어 둘 다 처리
    var bodyData: Data? {
        if let body = httpBody { return body }
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let size = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let n = stream.read(buffer, maxLength: size)
            if n <= 0 { break }
            data.append(buffer, count: n)
        }
        return data
    }
}

@Suite(.serialized)
struct ClipnoteAPITests {
    private func makeAPI() -> ClipnoteAPI {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return ClipnoteAPI(baseURL: URL(string: "http://stub.local:8787")!,
                           session: URLSession(configuration: config))
    }
    private func reset() {
        StubURLProtocol.handler = nil
        StubURLProtocol.networkError = nil
        StubURLProtocol.capturedRequest = nil
        StubURLProtocol.capturedBody = nil
    }

    @Test func successDecodesAndPreservesRawAnalysis() async throws {
        defer { reset() }
        let fixture = try Bundle.fixtureData("analyze-response")
        StubURLProtocol.handler = { _ in (200, fixture) }
        let result = try await makeAPI().analyze(
            videoURL: "https://m.youtube.com/watch?v=dQw4w9WgXcQ",
            profile: "generic", language: "ko", duration: 90, geminiKey: "test-key")
        #expect(result.videoId == "dQw4w9WgXcQ")
        #expect(result.analysis.steps.count == 2)
        let raw = try JSONSerialization.jsonObject(with: result.rawAnalysis) as! [String: Any]
        #expect(raw["_model"] as? String == "gemini-flash-lite-latest")  // 모델에 없는 키 보존

        // 요청 형태 검증 — 핸들러 클로저 안 #expect는 Swift Testing 컨텍스트에 전파되지 않아
        // 위반이 배너에서 위장되므로(리뷰 확인) 캡처 후 테스트 본문에서 단언한다.
        let request = try #require(StubURLProtocol.capturedRequest)
        #expect(request.url?.path == "/v1/analyze")
        #expect(request.value(forHTTPHeaderField: "X-Gemini-Key") == "test-key")
        let body = try JSONSerialization.jsonObject(
            with: try #require(StubURLProtocol.capturedBody)) as! [String: Any]
        #expect(body["duration"] as? Int == 90)          // 결정 #3: duration은 앱이 보낸다
        #expect(body["max_guides"] as? Int == 5)
        #expect(body["model"] == nil)                    // 서버 기본값 사용
    }

    @Test func maps401ToMissingKey() async throws {
        defer { reset() }
        StubURLProtocol.handler = { _ in
            (401, Data(#"{"detail": "X-Gemini-Key 헤더가 필요합니다."}"#.utf8))
        }
        await #expect(throws: ClipnoteAPIError.missingKey) {
            _ = try await self.makeAPI().analyze(
                videoURL: "u", profile: "generic", language: "ko", duration: 10, geminiKey: "k")
        }
    }

    @Test func maps422To429To502() async throws {
        defer { reset() }
        StubURLProtocol.handler = { _ in (422, Data(#"{"detail": "bad url"}"#.utf8)) }
        await #expect(throws: ClipnoteAPIError.badRequest("bad url")) {
            _ = try await self.makeAPI().analyze(
                videoURL: "u", profile: "generic", language: "ko", duration: 10, geminiKey: "k")
        }
        StubURLProtocol.handler = { _ in (429, Data(#"{"detail": "quota"}"#.utf8)) }
        await #expect(throws: ClipnoteAPIError.rateLimited) {
            _ = try await self.makeAPI().analyze(
                videoURL: "u", profile: "generic", language: "ko", duration: 10, geminiKey: "k")
        }
        // FastAPI는 detail이 객체일 수도 있음 (계약 위반 케이스)
        StubURLProtocol.handler = { _ in
            (502, Data(#"{"detail": {"message": "분석 결과 계약 위반", "errors": ["steps"]}}"#.utf8))
        }
        do {
            _ = try await makeAPI().analyze(
                videoURL: "u", profile: "generic", language: "ko", duration: 10, geminiKey: "k")
            Issue.record("should throw")
        } catch let error as ClipnoteAPIError {
            guard case .modelFailure(let detail) = error else {
                Issue.record("wrong case: \(error)"); return
            }
            #expect(detail.contains("계약 위반"))
        }
    }

    @Test func mapsTransportErrorToNetwork() async throws {
        defer { reset() }
        StubURLProtocol.networkError = URLError(.cannotConnectToHost)
        do {
            _ = try await makeAPI().analyze(
                videoURL: "u", profile: "generic", language: "ko", duration: 10, geminiKey: "k")
            Issue.record("should throw")
        } catch let error as ClipnoteAPIError {
            guard case .network = error else { Issue.record("wrong case: \(error)"); return }
        }
    }
}
