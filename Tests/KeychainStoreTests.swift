import Testing
import Foundation
@testable import clipnote

struct KeychainStoreTests {
    @Test func roundTripSaveLoadOverwriteDelete() throws {
        let store = KeychainStore(service: "clipnote.tests.\(UUID().uuidString)")
        defer { try? store.delete() }

        #expect(try store.load() == nil)
        try store.save("key-1")
        #expect(try store.load() == "key-1")
        try store.save("key-2")                 // 덮어쓰기
        #expect(try store.load() == "key-2")
        try store.delete()
        #expect(try store.load() == nil)
        try store.delete()                      // 없는 항목 삭제도 에러 아님
    }
}
