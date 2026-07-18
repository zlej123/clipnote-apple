#!/bin/bash
# skill-core 템플릿을 앱 리소스로 복사 (원본: ../clipnote). 코어 템플릿 갱신 시 재실행 후 골든 재생성.
set -euo pipefail
cd "$(dirname "$0")/.."
SRC="${CLIPNOTE_PATH:-../clipnote}/skill-core/profiles"
for p in generic recipe; do
  mkdir -p "Resources/skill-core/$p"
  cp "$SRC/$p/template.md" "Resources/skill-core/$p/template.md"
done
echo "synced templates from $SRC"
