import Foundation

enum NotionAPIError: Error, Equatable, LocalizedError {
    case invalidToken        // 401
    case parentNotFound      // 404
    case rateLimited         // 429
    case api(Int, String)    // 기타 — Notion 에러 body의 message
    case network(String)

    var errorDescription: String? {
        switch self {
        case .invalidToken: "Notion 토큰이 유효하지 않습니다 — 설정을 확인하세요"
        case .parentNotFound: "부모 페이지를 찾을 수 없습니다 — 페이지 ID와 통합 연결(페이지 ··· → 연결)을 확인하세요"
        case .rateLimited: "Notion 요청 한도 도달 — 잠시 후 다시 시도해 주세요"
        case .api(let code, let message): "Notion 오류 (HTTP \(code)) — \(message)"
        case .network: "Notion에 연결할 수 없습니다 — 네트워크를 확인하세요"
        }
    }
}

/// Notion 공식 API 클라이언트 (BYOT). 코어 export.py의 notion_request/notion_upload_image 포팅.
/// 토큰은 Authorization 헤더 세팅 외 어디에도 쓰지 않는다.
final class NotionAPI: Sendable {
    static let version = "2022-06-28"   // 코어와 동일 고정
    private static let base = URL(string: "https://api.notion.com/v1")!
    private let token: String
    private let session: URLSession

    init(token: String, session: URLSession = .shared) {
        self.token = token
        self.session = session
    }

    private func request(path: String, jsonBody: [String: Any]? = nil,
                         rawBody: (data: Data, contentType: String)? = nil)
        async throws -> [String: Any] {
        var request = URLRequest(url: Self.base.appending(path: path))
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Self.version, forHTTPHeaderField: "Notion-Version")
        if let jsonBody {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: jsonBody)
        } else if let rawBody {
            request.setValue(rawBody.contentType, forHTTPHeaderField: "Content-Type")
            request.httpBody = rawBody.data
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw NotionAPIError.network(String(describing: error))
        }
        guard let http = response as? HTTPURLResponse else {
            throw NotionAPIError.api(0, "응답 해석 불가")
        }
        switch http.statusCode {
        case 200...299: break
        case 401: throw NotionAPIError.invalidToken
        case 404: throw NotionAPIError.parentNotFound
        case 429: throw NotionAPIError.rateLimited
        default: throw NotionAPIError.api(http.statusCode, Self.message(from: data))
        }
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private static func message(from data: Data) -> String {
        ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])?["message"]
            as? String ?? ""
    }

    func createFileUpload() async throws -> String {
        let object = try await request(path: "/file_uploads", jsonBody: [:])
        guard let id = object["id"] as? String else {
            throw NotionAPIError.api(200, "file_upload id 없음")
        }
        return id
    }

    /// 코어 notion_upload_image(export.py 228~241행)의 멀티파트 바디 조립부 포팅.
    /// 바이트 시퀀스(명시적 문자열 연결로 CRLF 이스케이프 실수 여지 제거 — 브리프 주의사항 반영):
    ///   --{boundary}\r\n
    ///   Content-Disposition: form-data; name="file"; filename="{filename}"\r\n
    ///   Content-Type: {mime}\r\n\r\n
    ///   {raw bytes}
    ///   \r\n--{boundary}--\r\n
    func sendFileUpload(id: String, data: Data, filename: String,
                        mime: String = "image/jpeg") async throws {
        let boundary = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let head = "--" + boundary + "\r\n"
            + "Content-Disposition: form-data; name=\"file\"; filename=\"" + filename + "\"\r\n"
            + "Content-Type: " + mime + "\r\n\r\n"
        var body = Data(head.utf8)
        body.append(data)
        body.append(Data(("\r\n--" + boundary + "--\r\n").utf8))
        _ = try await request(path: "/file_uploads/\(id)/send",
                              rawBody: (body, "multipart/form-data; boundary=\(boundary)"))
    }

    func createPage(parentPageID: String, title: String,
                    children: [NotionBlock]) async throws -> (id: String, url: String?) {
        let object = try await request(path: "/pages", jsonBody: [
            "parent": ["page_id": parentPageID],
            "properties": ["title": ["title": NotionBlockBuilder.rich(title)]],
            "children": children,
        ])
        guard let id = object["id"] as? String else {
            throw NotionAPIError.api(200, "page id 없음")
        }
        return (id, object["url"] as? String)
    }

    func appendChildren(pageID: String, blocks: [NotionBlock]) async throws {
        _ = try await request(path: "/blocks/\(pageID)/children",
                              jsonBody: ["children": blocks])
    }
}
