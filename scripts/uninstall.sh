#!/bin/zsh
# 미니 어항을 완전히 삭제한다: 앱, 자동 실행 등록, 손쉬운 사용 권한 기록, 저장된 설정.
# Fully removes Mini Aquarium: the app, login item, Accessibility entry and saved settings.
# (앱을 휴지통에 버리기만 하면 권한 기록과 설정이 남는다. / Trashing the app alone leaves those behind.)
APP="/Applications/MiniAquarium.app"
ID="local.mini-aquarium"

if defaults read -g AppleLanguages 2>/dev/null | grep -q '"ko'; then KO=1; else KO=0; fi
say() { if [ "$KO" = 1 ]; then echo "$1"; else echo "$2"; fi }

say "미니 어항을 삭제합니다..." "Uninstalling Mini Aquarium..."
pkill -x MiniAquarium 2>/dev/null; sleep 1
# 번들 ID가 살아 있을 때(앱 삭제 전) 해야 권한 기록이 지워진다. / Must run before the app is deleted.
[ -x "$APP/Contents/MacOS/MiniAquarium" ] && "$APP/Contents/MacOS/MiniAquarium" --uninstall
tccutil reset Accessibility "$ID" >/dev/null 2>&1 && say "- 손쉬운 사용 권한 기록 삭제" "- Accessibility entry removed"
defaults delete "$ID" 2>/dev/null && say "- 저장된 설정 삭제" "- Saved settings removed"
if [ -d "$APP" ]; then rm -rf "$APP" && say "- 앱 삭제: $APP" "- App removed: $APP"; else say "- 설치된 앱이 없어요" "- App is not installed"; fi
say "끝났어요. (시스템 설정 > 손쉬운 사용 목록에 이름만 남아 있으면 '−'로 지워 주세요)" "Done. (If the name still shows in System Settings > Accessibility, remove it with '−'.)"
