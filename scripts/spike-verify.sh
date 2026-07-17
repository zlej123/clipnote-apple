#!/bin/bash
# M0 스파이크: 시뮬레이터에서 앱을 실행해 캡처를 수행하고 result.json을 판정한다.
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
cd "$(dirname "$0")/.."
SIM="iPhone 17 Pro"
BUNDLE=com.clipnote.app

xcodebuild -project clipnote-apple.xcodeproj -scheme Clipnote \
  -destination "platform=iOS Simulator,name=$SIM" -derivedDataPath build build | tail -2
xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl install "$SIM" build/Build/Products/Debug-iphonesimulator/clipnote.app
xcrun simctl terminate "$SIM" $BUNDLE 2>/dev/null || true
SIMCTL_CHILD_CLIPNOTE_SPIKE=1 xcrun simctl launch "$SIM" $BUNDLE

# 스파이크 하네스는 홈 화면에서 진입해야 하므로 UI 없이는 자동 진입이 안 된다 →
# 앱 시작 시 CLIPNOTE_SPIKE=1이면 스파이크 뷰를 루트로 띄우는 분기가 ClipnoteApp에 필요(Step 8).
CONTAINER=$(xcrun simctl get_app_container "$SIM" $BUNDLE data)
RESULT="$CONTAINER/Documents/spike/result.json"
echo "waiting for $RESULT"
for i in $(seq 1 60); do
  [ -f "$RESULT" ] && break
  sleep 2
done
[ -f "$RESULT" ] || { echo "SPIKE FAIL: result.json not produced"; exit 1; }
cat "$RESULT"
python3 - "$RESULT" <<'EOF'
import json, sys
r = json.load(open(sys.argv[1]))
assert r.get("ok"), f"spike not ok: {r}"
print("SPIKE PASS (iOS simulator)")
EOF
