import Foundation

indirect enum MustacheValue: Sendable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case list([MustacheValue])
    case dict([String: MustacheValue])
    case null
}

/// 코어 render.py의 미니 mustache 렌더러 포팅 (sections/inverted/vars, 스택 lookup, 중첩).
/// 파이썬과의 출력 파리티가 목적 — 골든 테스트(Task 5)가 기준. 동작을 "개선"하지 말 것.
enum MustacheLite {
    struct UnclosedSection: Error { let key: String }

    // 컴파일러 강제 어댑테이션(Swift 6 strict concurrency, Task 3와 동일 사유):
    // Regex<...>가 Sendable로 추론되지 않아 static let 저장 프로퍼티가 거부됨.
    // token이 parse/captureBlock 두 곳에서 쓰이므로 리터럴 중복 대신 computed property로 해소.
    private static var token: Regex<(Substring, Substring, Substring)> {
        /\{\{([#^\/]?)\s*([\w.]+)\s*\}\}/
    }
    // (?m)^[ \t]*({{[#^/]key}})[ \t]*\r?\n → \1 : standalone 섹션 태그 줄의 들여쓰기+개행 제거
    private static var standaloneLine: Regex<(Substring, Substring)> {
        /(?m)^[ \t]*(\{\{[#^\/][\w.]+\}\})[ \t]*\r?\n/
    }

    static func render(_ template: String, _ data: MustacheValue) throws -> String {
        let cleaned = template.replacing(standaloneLine) { String($0.output.1) }
        return try parse(cleaned[...], [data]).out
    }

    private static func parse(_ text: Substring, _ stack: [MustacheValue]) throws
        -> (out: String, stopped: Bool) {
        var out = ""
        var rest = text
        while let m = rest.firstMatch(of: token) {
            out.append(contentsOf: rest[..<m.range.lowerBound])
            let sigil = String(m.output.1)
            let key = String(m.output.2)
            switch sigil {
            case "#", "^":
                let block = try captureBlock(rest[m.range.upperBound...], key: key)
                let val = lookup(stack, key)
                if sigil == "#" {
                    switch val {
                    case .list(let items):
                        for item in items { out += try parse(block.inner, stack + [item]).out }
                    case .dict:
                        out += try parse(block.inner, stack + [val]).out
                    default:
                        if isTruthy(val) { out += try parse(block.inner, stack).out }
                    }
                } else if !isTruthy(val) {
                    out += try parse(block.inner, stack).out
                }
                rest = block.after
            case "/":
                return (out, true) // 파이썬 동작: 고아 닫힘 태그에서 그대로 반환
            default:
                out += stringify(lookup(stack, key))
                rest = rest[m.range.upperBound...]
            }
        }
        out.append(contentsOf: rest)
        return (out, false)
    }

    private static func captureBlock(_ text: Substring, key: String) throws
        -> (inner: Substring, after: Substring) {
        var depth = 1
        var rest = text
        while let m = rest.firstMatch(of: token) {
            let sigil = String(m.output.1)
            let k = String(m.output.2)
            if (sigil == "#" || sigil == "^") && k == key {
                depth += 1
            } else if sigil == "/" && k == key {
                depth -= 1
                if depth == 0 {
                    return (text[..<m.range.lowerBound], rest[m.range.upperBound...])
                }
            }
            rest = rest[m.range.upperBound...]
        }
        throw UnclosedSection(key: key)
    }

    private static func lookup(_ stack: [MustacheValue], _ key: String) -> MustacheValue {
        for ctx in stack.reversed() {
            if case .dict(let entries) = ctx, let value = entries[key] { return value }
        }
        return .null
    }

    /// 파이썬 truthy: bool(v) and v != [] and v != ""
    private static func isTruthy(_ value: MustacheValue) -> Bool {
        switch value {
        case .null: false
        case .bool(let b): b
        case .int(let i): i != 0
        case .double(let d): d != 0
        case .string(let s): !s.isEmpty
        case .list(let l): !l.isEmpty
        case .dict(let d): !d.isEmpty
        }
    }

    /// 파이썬 str() 대응 (None → "")
    private static func stringify(_ value: MustacheValue) -> String {
        switch value {
        case .null: ""
        case .string(let s): s
        case .int(let i): String(i)
        case .double(let d): String(d)
        case .bool(let b): b ? "True" : "False"
        case .list, .dict: "" // 템플릿에서 컬렉션을 변수로 쓰지 않음
        }
    }
}
