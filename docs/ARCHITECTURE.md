# 구조

```
Sources/
├── MiniAquariumCore/   순수 로직 (UI 의존 없음, 테스트 대상)
│   ├── Simulation      물고기 움직임·먹이·갉아먹기, 이음새(seam) 대시
│   ├── Settings        AquariumSettings (Codable 값 타입, 관대한 디코딩)
│   ├── DockFit         Dock 방향·두께·빈 자리 계산 (DockRegion)
│   ├── Language        한국어/English 선택 (Language.current, 시스템 언어 기본값)
│   ├── Species/Decor/FoodKind/TankShape/TankSize/Layout   어항 구성 요소 정의
│   └── TimerState      타이머 진행률
└── MiniAquarium/       AppKit + SwiftUI 앱
    ├── AppDelegate     패널 두 개(앞/뒤), 메뉴바 아이템, Dock 0.5초 갱신
    ├── AquariumModel   설정·시뮬레이션·타이머를 묶는 ObservableObject
    ├── DockPlacement   Dock 설정/실행 앱으로 아이콘 수 어림 + 손쉬운 사용(AX)으로 실측
    ├── TankView / TankRenderer / PortalOverlay   그리기
    ├── FishArt(+More) / DecorArt / FoodArt        벡터 아트
    ├── SettingsPanel   설정 UI (타이머·어항·물고기·꾸미기·정보)
    ├── AppInfo         버전·제작자, 로그인 시 자동 실행(SMAppService)
    └── Snapshot        --snapshot PNG 렌더링 (화면 녹화 권한 불필요)
Tests/MiniAquariumCoreTests/   Swift Testing
scripts/make-app.sh      .app 번들 (아이콘·Info.plist·현지화·애드혹 서명)
scripts/make-dmg.sh      dmg (배경 그림·아이콘 배치·볼륨 아이콘, dmgbuild 사용)
scripts/uninstall.sh     앱·자동 실행·권한 기록·설정 완전 삭제
```

## 핵심 개념

- **떠 있는 투명 패널**: `NSPanel`(포커스를 뺏지 않음, 모든 Space)이 `TankView`를 호스팅해요.
- **이어진 긴 어항('양쪽')**: 모델의 `dockedSize`가 두 띠를 합친 하나의 월드이고, 패널마다 `viewport`(이동+클립)로 일부만 보여줘요. 이음새는 `Simulation.seam`이고 건널 때 `Fish.dash`로 잠깐 빨라져요. 이음새 쪽 모서리는 둥글게(`seamShape`) 잘리고 `PortalOverlay`가 포털을 그려요.
- **Dock 맞춤**: `DockFit.region`이 `screen`과 `visibleFrame`의 차이로 Dock 방향과 두께를 알아내고, 아이콘 줄(알약)의 위치를 (권한이 있으면) AX로 실측, 없으면 개수로 어림해요. `gap`은 Dock과 어항 사이 간격이에요.
- **설정 저장**: `SettingsStore`가 `UserDefaults`에 JSON으로 저장해요. 필드는 `try?`로 하나씩 디코딩해서 예전 저장값이 있어도 기본값으로 채워져요.
- **언어**: `Language.current`를 설정(`AquariumSettings.language`)과 동기화해서 UI 문자열이 즉시 바뀌어요. 번들에도 en/ko `InfoPlist.strings`가 들어 있어요.
- **권한/서명**: 손쉬운 사용 권한은 코드 서명 요구사항에 묶여요. [배포 가이드](RELEASING.md) 참고.
