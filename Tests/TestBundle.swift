import Foundation

final class TestBundleToken {}

extension Bundle {
    static var tests: Bundle { Bundle(for: TestBundleToken.self) }

    /// 폴더 레퍼런스로 복사된 Fixtures에서 로드. subdirectory는 "Fixtures" 기준 하위 경로.
    static func fixtureData(_ name: String, ext: String = "json",
                            subdirectory: String = "Fixtures") throws -> Data {
        guard let url = tests.url(forResource: name, withExtension: ext, subdirectory: subdirectory) else {
            throw NSError(domain: "fixture", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "fixture not found: \(subdirectory)/\(name).\(ext)"])
        }
        return try Data(contentsOf: url)
    }
}
