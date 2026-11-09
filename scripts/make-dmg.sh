#!/bin/zsh
# 배포용 .dmg를 만든다. 먼저 make-app.sh로 .app을 만들고, Applications 바로가기가 든 디스크 이미지로 묶는다.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(grep -A1 CFBundleShortVersionString scripts/make-app.sh | grep -o '<string>[^<]*' | head -1 | sed 's/<string>//')"
NAME="MiniAquarium-${VERSION}"
STAGE="$(mktemp -d)/dmg"
OUT="build/${NAME}.dmg"

zsh scripts/make-app.sh
mkdir -p "$STAGE"
cp -R build/MiniAquarium.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"

rm -f "$OUT"
hdiutil create -volname "미니 어항 ${VERSION}" -srcfolder "$STAGE" -ov -format UDZO "$OUT" >/dev/null
rm -rf "$(dirname "$STAGE")"

echo "만들어짐: $PWD/$OUT"
shasum -a 256 "$OUT"
