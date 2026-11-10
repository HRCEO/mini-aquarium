# TODO — Apple 등록·배포·판매 계획

> 최종 확인: 2026-11-09. Apple 정책·요금·화면은 자주 바뀌니 실제 진행 전에 공식 문서로 다시 확인하세요.
> 1.x는 **무료 배포**, 유료 판매는 **2.0**에서 추가합니다.

## 로드맵

| 버전 | 목표 | 배포 방식 |
|---|---|---|
| 1.0 (현재) | 무료, GitHub 릴리스 | 애드혹 서명 dmg (첫 실행이 막힐 수 있음) |
| 1.x | 경고 없이 설치되게 | Developer ID 서명 + 공증(notarization) dmg |
| 2.0 | 유료 판매 | 아래 [판매 방식](#20-유료-판매-방식-결정-필요) 중 선택 |

## 가장 먼저 정할 것

- [ ] **Mac App Store(MAS)를 갈지, 직접 배포(Developer ID)만 할지**
  - MAS는 **App Sandbox가 필수**인데, 이 앱은 Dock 아이콘 줄의 실제 길이를 읽으려고 **손쉬운 사용(AX) API**와 Dock 설정을 써요. 샌드박스 안에서는 이 방식이 막히거나 심사에서 거절될 가능성이 커요. 권한 없이 쓰는 어림 모드가 있어 최소 동작은 하지만, **Dock에 딱 맞는 어항**이라는 핵심 기능이 약해질 수 있어요.
  - 그래서 기본 방향은 **Developer ID 직접 배포**, MAS는 샌드박스 호환성을 따로 검증한 뒤 결정해요.
- [ ] 번들 ID 확정: 지금은 `local.mini-aquarium`. 정식 배포 전에 역도메인(`com.<소유한 도메인>.mini-aquarium` 등)으로 바꿔야 해요. 바꾸면 사용자의 **손쉬운 사용 권한과 저장된 설정(UserDefaults)이 초기화**되므로 한 번만, 가능한 한 일찍 바꿔요. 설정 이전 코드가 필요할지 검토해요.
- [ ] 개인 계정 vs 조직 계정: 유료 판매와 판매자 이름 표시(개인 실명이 노출됨)를 고려해 결정해요. 조직은 D-U-N-S 번호가 필요해요.

## A. Apple Developer Program 가입 (공통 선행)

- [ ] Apple ID에 2단계 인증 켜기
- [ ] https://developer.apple.com/programs/enroll/ 에서 가입 (연 99 USD, 매년 갱신)
- [ ] 가입 승인 대기 (보통 수 시간~수 일, 조직은 더 걸림)

## B. 직접 배포: Developer ID 서명 + 공증 (1.x 목표)

1. [ ] **인증서 만들기**: Xcode → Settings → Accounts → Manage Certificates에서 `Developer ID Application` 추가 (또는 developer.apple.com에서 CSR로 발급). 키체인에 개인 키가 있는지 확인하고 **백업**해요.
2. [ ] **`scripts/make-app.sh` 서명 변경**
   - 현재: `codesign --force --sign - -r='designated => identifier "local.mini-aquarium"'` (애드혹)
   - 변경: `codesign --force --options runtime --timestamp --sign "Developer ID Application: <이름> (<TEAMID>)" build/MiniAquarium.app`
   - 손쉬운 사용 권한이 서명 요구사항에 묶이므로, 기존 사용자는 **업데이트 후 권한을 한 번 다시 켜야 할 수 있어요.** 릴리스 노트에 적어요. (인증서가 같으면 이후 업데이트에서는 유지돼요.)
3. [ ] **dmg도 서명**: `codesign --sign "Developer ID Application: …" build/MiniAquarium-<버전>.dmg`
4. [ ] **공증 자격 저장** (한 번만): App 암호 또는 API 키로
   ```bash
   xcrun notarytool store-credentials "mini-aquarium-notary" \
     --apple-id "<Apple ID>" --team-id "<TEAMID>" --password "<app-specific password>"
   ```
5. [ ] **공증 제출**:
   ```bash
   xcrun notarytool submit build/MiniAquarium-<버전>.dmg --keychain-profile "mini-aquarium-notary" --wait
   ```
   실패하면 `xcrun notarytool log <submission-id> --keychain-profile …`로 이유를 확인해요.
6. [ ] **스테이플**: `xcrun stapler staple build/MiniAquarium-<버전>.dmg`
7. [ ] **검증**: `spctl --assess --type open --context context:primary-signature -v build/MiniAquarium-<버전>.dmg`, `xcrun stapler validate …`. **다른 Mac(또는 새 사용자 계정)에서 내려받아 경고 없이 열리는지** 확인해요.
8. [ ] `make-dmg.sh`에 서명→공증→스테이플을 옵션으로 넣기 (`NOTARIZE=1 bash scripts/make-dmg.sh` 같은 형태), 키·암호는 환경 변수/키체인으로만 다루고 **저장소에 넣지 않기**
9. [ ] README의 `xattr` 안내와 "손상되어 열 수 없음" 항목 정리, `docs/RELEASING.md` 갱신
10. [ ] (선택) 자동 업데이트: Sparkle 도입 검토 (서명 키 별도 관리)

## C. Mac App Store 등록 (선택)

- [ ] **샌드박스 호환성 먼저 검증**: App Sandbox 켠 빌드에서 Dock 맞춤·AX 실측·자동 실행(`SMAppService`)이 어디까지 되는지 확인. 안 되는 기능의 대체안(어림 모드만, 기능 축소 등)을 정해요.
- [ ] Xcode 프로젝트(또는 패키징 스크립트) 준비: 지금은 SwiftPM 기반이라 MAS용 `.app` 서명·프로비저닝 프로파일 포함·`.pkg` 생성 절차가 필요해요.
- [ ] 인증서: `Apple Distribution`(앱 서명), `Mac Installer Distribution`(pkg 서명), Mac App Store 프로비저닝 프로파일
- [ ] 엔타이틀먼트: `com.apple.security.app-sandbox` 등 필요한 최소 권한만
- [ ] App Store Connect에서 앱 레코드 생성 (번들 ID, 이름, SKU, 기본 언어)
- [ ] 업로드: Transporter 또는 `xcrun altool`/Xcode Organizer
- [ ] 메타데이터: 설명(한/영), 키워드, 카테고리, 스크린샷(Mac 해상도 규격), 지원 URL, **개인정보 처리방침 URL**, 앱 개인정보 항목(수집 없음이면 "데이터 수집 안 함"), 연령 등급, 수출 규정(암호화 사용 여부)
- [ ] 심사 제출 → 거절 시 사유 대응 (특히 손쉬운 사용 권한 사용 목적 설명)

## 2.0 유료 판매 방식 (결정 필요)

| 방식 | 장점 | 단점 |
|---|---|---|
| **Mac App Store 유료/인앱 결제** | 결제·세금·배포 Apple이 처리, 신뢰도 | 샌드박스 제약, 수수료 15~30% (소규모 사업자 프로그램은 15%), 심사 |
| **직접 판매 + 라이선스 키** (Paddle, Lemon Squeezy, Gumroad 등 판매 대행) | 샌드박스 제약 없음, 판매 대행사가 세금 처리, 체험판 설계 자유 | 라이선스 검증·업데이트(Sparkle)·환불 직접 구축/관리 |
| 하이브리드 | 두 채널 병행 | 두 벌 유지 비용 |

판매 전 확인할 것:

- [ ] 가격·모델 결정: 유료 앱 / 체험판 후 구매 / 무료 + 프로 기능 (기능 분리 범위 정하기)
- [ ] **사업자 등록 여부와 세금**: 한국에서 수익이 생기면 개인 사업자 등록·부가세·종합소득세 등이 관련돼요. 해외 판매 대행사/Apple 정산 방식에 따라 달라지니 **세무 전문가·국세청 안내로 확인**해요.
- [ ] MAS라면: App Store Connect의 **유료 앱 계약(Paid Applications Agreement)**, 은행 계좌, 세금 양식(한국 거주자는 보통 W-8BEN 계열) 작성
- [ ] 이용약관·환불 정책·개인정보 처리방침 문서 준비, `LICENSE` 정리 (지금은 MIT라서 누구나 코드를 쓰고 팔 수 있어요. 유료 2.0의 소스를 공개하지 않거나 제한하려면 2.0 코드는 별도 저장소·라이선스로 분리하는 방안을 검토해요. 이미 공개한 1.x의 MIT는 되돌릴 수 없어요)
- [ ] 라이선스 키 방식이면: 키 발급·검증·기기 제한·오프라인 동작 설계
- [ ] 지원 창구(이메일/이슈), 웹사이트(랜딩 페이지), 상표·앱 이름 중복 확인

## 참고 문서

- Apple Developer Program: https://developer.apple.com/programs/
- 공증: https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
- Developer ID: https://developer.apple.com/support/developer-id/
- App Store 심사 지침: https://developer.apple.com/app-store/review/guidelines/
- App Sandbox: https://developer.apple.com/documentation/security/app-sandbox
- Sparkle: https://sparkle-project.org/
