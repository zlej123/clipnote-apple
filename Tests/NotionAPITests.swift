import Testing
import Foundation
@testable import clipnote

@Suite(.serialized)
struct NotionAPITests {
    private func makeAPI() -> NotionAPI {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return NotionAPI(token: "test-token", session: URLSession(configuration: config))
    }
    private func reset() {
        StubURLProtocol.handler = nil
        StubURLProtocol.networkError = nil
        StubURLProtocol.capturedRequest = nil
        StubURLProtocol.capturedBody = nil
    }

    @Test func fileUploadTwoStepSequence() async throws {
        defer { reset() }
        StubURLProtocol.handler = { request in
            if request.url!.path == "/v1/file_uploads" {
                return (200, Data(#"{"id": "fu-123"}"#.utf8))
            }
            return (200, Data("{}".utf8))
        }
        let api = makeAPI()
        let id = try await api.createFileUpload()
        #expect(id == "fu-123")

        try await api.sendFileUpload(id: id, data: Data([0xFF, 0xD8]), filename: "vg-1.jpg")
        let request = try #require(StubURLProtocol.capturedRequest)
        #expect(request.url?.path == "/v1/file_uploads/fu-123/send")
        #expect(request.value(forHTTPHeaderField: "Content-Type")?
            .hasPrefix("multipart/form-data; boundary=") == true)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
        #expect(request.value(forHTTPHeaderField: "Notion-Version") == "2022-06-28")
        let body = try #require(StubURLProtocol.capturedBody)
        let bodyText = String(decoding: body, as: UTF8.self)
        #expect(bodyText.contains(#"filename="vg-1.jpg""#))
    }

    @Test func createPagePayloadAndURL() async throws {
        defer { reset() }
        StubURLProtocol.handler = { _ in
            (200, Data(#"{"id": "page-1", "url": "https://www.notion.so/page-1"}"#.utf8))
        }
        let api = makeAPI()
        let blocks: [NotionBlock] = [["type": "paragraph",
                                      "paragraph": ["rich_text": NotionBlockBuilder.rich("x")]]]
        let page = try await api.createPage(parentPageID: "p" + String(repeating: "0", count: 31),
                                            title: "제목", children: blocks)
        #expect(page.id == "page-1")
        #expect(page.url == "https://www.notion.so/page-1")
        let request = try #require(StubURLProtocol.capturedRequest)
        #expect(request.url?.path == "/v1/pages")
        let payload = try JSONSerialization.jsonObject(
            with: try #require(StubURLProtocol.capturedBody)) as! [String: Any]
        let parent = payload["parent"] as! [String: Any]
        #expect(parent["page_id"] as? String == "p" + String(repeating: "0", count: 31))
        #expect((payload["children"] as! [Any]).count == 1)
        let title = ((payload["properties"] as! [String: Any])["title"] as! [String: Any])["title"] as! [[String: Any]]
        #expect(((title[0]["text"] as! [String: Any])["content"] as? String) == "제목")
    }

    @Test func mapsErrorStatuses() async throws {
        defer { reset() }
        let api = makeAPI()
        StubURLProtocol.handler = { _ in (401, Data(#"{"message": "unauthorized"}"#.utf8)) }
        await #expect(throws: NotionAPIError.invalidToken) { _ = try await api.createFileUpload() }
        StubURLProtocol.handler = { _ in (404, Data(#"{"message": "not found"}"#.utf8)) }
        await #expect(throws: NotionAPIError.parentNotFound) { _ = try await api.createFileUpload() }
        StubURLProtocol.handler = { _ in (429, Data(#"{"message": "rate"}"#.utf8)) }
        await #expect(throws: NotionAPIError.rateLimited) { _ = try await api.createFileUpload() }
        StubURLProtocol.handler = { _ in (400, Data(#"{"message": "bad block"}"#.utf8)) }
        await #expect(throws: NotionAPIError.api(400, "bad block")) { _ = try await api.createFileUpload() }
    }
}
