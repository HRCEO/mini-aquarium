# 배포 가이드

## 한 줄 요약

```bash
bash scripts/make-dmg.sh
# → build/MiniAquarium-<버전>.dmg  (SHA-256도 함께 출력)
```

## 1. 버전 올리기

버전은 `scripts/make-app.sh`의 `CFBundleShortVersionString` 한 곳에만 있어요. 앱의 "정보" 탭과 dmg 파일 이름이 여기서 따라와요.

```bash
sed -i '' 's|<key>CFBundleShortVersionString</key><string>1.0.0</string>|<key>CFBundleShortVersionString</key><string>1.1.0</string>|' scripts/make-app.sh
```

## 2. 확인

```bash
swift build && swift test          # 테스트 (Xcode 툴체인 필요)
bash scripts/make-app.sh
open build/MiniAquarium.app        # 직접 실행해 보기
```

## 3. dmg 만들기

```bash
bash scripts/make-dmg.sh
```

`build/MiniAquarium-<버전>.dmg` 안에는 앱과 Applications 바로가기가 들어 있고, 배경 그림·아이콘 배치·볼륨 아이콘이 적용돼요. 배경은 앱 바이너리의 `--dmg-bg`로 그려요. 처음 한 번 `dmgbuild`를 `build/.venv`에 설치해요(인터넷 필요). 완성되면 중간 결과물인 `build/MiniAquarium.app`은 지워요.

## 4. GitHub 릴리스 올리기

```bash
git tag v1.0.0 && git push origin v1.0.0
gh release create v1.0.0 build/MiniAquarium-1.0.0.dmg \
  --title "v1.0.0" --notes "첫 릴리스"
```

## 서명과 공증(notarization)

지금 빌드는 **애드혹 서명**이라 개발자 계정이 필요 없어요. 대신 받는 사람의 Mac이 처음 실행을 막을 수 있어서 README의 `xattr` 안내가 필요해요.

- 손쉬운 사용 권한은 서명의 *designated requirement*(`identifier "local.mini-aquarium"`)에 묶여 있어요. 다시 빌드해도 권한이 유지되도록 `make-app.sh`가 이 요구사항을 고정해서 서명해요. 이 식별자나 서명 방식을 바꾸면 사용자가 권한을 다시 켜야 해요.
- 경고 없이 배포하려면 Apple Developer Program(유료) 계정으로 `Developer ID Application` 인증서 서명 + `xcrun notarytool submit` + `xcrun stapler staple`이 필요해요. 자세한 절차와 순서는 [TODO.md](TODO.md)에 정리했어요. 요약하면 `make-app.sh`의 `codesign` 줄을 `--sign "Developer ID Application: …" --options runtime`으로 바꾸고, 권한 요구사항도 함께 정리하세요.

## 첫 저장소 올리기

```bash
cd mini-aquarium
git init
git add .
git commit -m "feat: mini aquarium 1.0.0"
git branch -M main
git remote add origin https://github.com/HRCEO/mini-aquarium.git
git push -u origin main
```
