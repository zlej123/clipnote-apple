# clipnote-apple

영상을 문서로, 레시피로, 사용매뉴얼로.
유튜브 how-to 영상을 단계별 문서로 만들고, "한입 크기" 같은 애매한 표현마다
실제 프레임(사용자가 선택)이나 타임스탬프 링크를 첨부하는 SwiftUI 앱 (iOS/iPadOS/macOS).
완성된 문서는 공유시트·폴더 저장 외에 Notion 페이지로도 직접 내보낼 수 있다(사용자 통합 토큰).

[clipnote](https://github.com/zlej123/clipnote) 생태계의 Apple 클라이언트 —
분석은 [clipnote-server](https://github.com/zlej123/clipnote-server)(BYOK, 사용자 Gemini 키),
캡처는 앱의 WKWebView(영상 다운로드 없음), 문서 조립은 로컬(skill-core 템플릿 + 코어 렌더러 포팅).

## 개발

요구: Xcode 26+, XcodeGen(`brew install xcodegen`), Python 3.10+(스크립트)

    xcodegen generate                # project.yml → xcodeproj
    open clipnote-apple.xcodeproj

    # 테스트 (CLI, xcode-select가 CLT면 DEVELOPER_DIR 지정)
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
    xcodebuild -project clipnote-apple.xcodeproj -scheme Clipnote -destination 'platform=macOS' test

    # E2E (스텁 서버 — Gemini 키 불필요)
    ./scripts/e2e-m1.sh              # 링크 모드
    ./scripts/e2e-m2.sh              # 실제 유튜브 캡처

## 스크립트
- `scripts/stub-server.py` — /v1/analyze 스텁 (fixture 응답)
- `scripts/sync-assets.sh` — ../clipnote skill-core 템플릿 재복사 (갱신 시 make-golden.py 재실행)
- `scripts/make-golden.py` — 코어 render.py로 골든 기대 출력 재생성
- `scripts/make-notion-golden.py` — 코어 build_notion_blocks로 Notion 블록 골든 재생성
- `scripts/spike-verify.sh` — M0 캡처 검증

## 문서
- 설계: `docs/superpowers/specs/2026-07-17-clipnote-apple-v1-design.md`
- 캡처 스파이크 기록: `docs/spike-capture.md`
- 수동 테스트: `docs/TESTING.md`
