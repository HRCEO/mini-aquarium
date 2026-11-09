#!/bin/zsh
# 배포용 .dmg를 만든다. make-app.sh로 .app을 만들고, 배경 그림·아이콘 배치·볼륨 아이콘이 든 디스크 이미지로 묶는다.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(grep -A1 CFBundleShortVersionString scripts/make-app.sh | grep -o '<string>[^<]*' | head -1 | sed 's/<string>//')"
NAME="MiniAquarium-${VERSION}"
VOL="Mini Aquarium ${VERSION}"
OUT="build/${NAME}.dmg"
WORK="$(mktemp -d)"
STAGE="$WORK/stage"
trap 'rm -rf "$WORK"' EXIT

zsh scripts/make-app.sh
BIN="$(swift build -c release --show-bin-path)/MiniAquarium"

mkdir -p "$STAGE/.background"
"$BIN" --dmg-bg "$STAGE/.background/bg.png"

# 창 배경·아이콘 위치·볼륨 아이콘은 dmgbuild로 .DS_Store에 직접 기록한다 (Finder 자동화 권한이 필요 없다).
# 처음 한 번만 build/.venv에 dmgbuild를 설치한다 (인터넷 필요).
if [ ! -x build/.venv/bin/dmgbuild ]; then
  python3 -m venv build/.venv
  build/.venv/bin/pip install -q dmgbuild
fi
cat > "$WORK/settings.py" <<PY
files = ["build/MiniAquarium.app"]
symlinks = {"Applications": "/Applications"}
icon = "build/MiniAquarium.app/Contents/Resources/AppIcon.icns"
background = "$STAGE/.background/bg.png"
window_rect = ((200, 120), (660, 400))
icon_size = 96
text_size = 12
show_status_bar = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
icon_locations = {
    "MiniAquarium.app": (165, 175),
    "Applications": (495, 175),
}
PY
rm -f "$OUT"
build/.venv/bin/dmgbuild -s "$WORK/settings.py" "$VOL" "$OUT" >/dev/null

# .dmg 파일 자체 아이콘 (이 맥에서만 보인다. 내려받으면 사라지는 Finder 메타데이터).
"$BIN" --set-file-icon "$OUT" build/MiniAquarium.app/Contents/Resources/AppIcon.icns 2>/dev/null || true

# dmg 안에 이미 들어 있으니 중간 결과물인 .app은 지운다 (앱만 필요하면 make-app.sh).
rm -rf build/MiniAquarium.app

echo "만들어짐: $PWD/$OUT"
shasum -a 256 "$OUT"
