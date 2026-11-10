# 구조

```
Sources/
├── MiniAquariumCore/   순수 로직 (UI 의존 없음, 테스트 대상)
│   ├── Simulation      물고기 움직임·먹이·갉아먹기, 이음새(seam) 대시
│   ├── Settings        AquariumSettings (Codable 값 타입, 관대한 디코딩)
│   ├── DockFit         Dock 방향·두께·빈 자리 계산 (DockRegion)
│   ├── DockLayout      빈 띠 → 패널 위치·크기·뷰포트·이음새 계산 (순수 계산)
│   ├── Language        한국어/English 선택 (Language.current, 시스템 언어 기본값)
│   ├── Species/Decor/FoodKind/TankShape/TankSize/Layout   어항 구성 요소 정의
│   ├── TimerState      타이머 진행률
│   ├── Pomodoro        PomodoroPlan(시간 구성)·PomodoroSession(집중↔휴식 순환)
│   └── SystemLoad      CPU·메모리·배터리 → 헤엄 속도·물 높이·탁함 매핑 (순수 계산)
└── MiniAquarium/       AppKit + SwiftUI 앱
    ├── AppDelegate     패널 두 개(앞/뒤), 메뉴바 아이템, DockLayout을 창에 적용
    ├── AquariumModel   설정·시뮬레이션·타이머를 묶는 ObservableObject
    ├── DockPlacement   Dock 설정/실행 앱으로 아이콘 수 어림 + 손쉬운 사용(AX)으로 실측
    ├── DockMonitor     Dock이 바뀌었을 수 있는 계기(0.5초 폴링, 화면 구성 변경)를 모아 알려줌
    ├── AquariumEvents  AquariumEvent + 핸들러(SoundAlert). 알림 방식을 추가하는 확장 지점
    ├── TankView / TankRenderer / PortalOverlay   그리기
    ├── FishArt(+More) / DecorArt / FoodArt        벡터 아트
    ├── SystemMonitor   host_statistics·IOKit.ps로 시스템 상태를 읽어 SystemLoad로 돌려줌
    ├── SettingsPanel   설정 UI (타이머·어항·물고기·꾸미기·정보)
    ├── PomodoroPanel   포모도로·시스템 연동 설정 컨트롤 (각각 on/off 스위치)
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

## Dock 처리 흐름

```
DockMonitor ──(바뀌었을 수 있음)──▶ AppDelegate.refreshDock()
                                      │
  DockPlacement.current()   Dock 설정 + AX로 아이콘 줄 영역을 읽음  (AppKit, 시스템 의존)
        ▼
  DockFit.region()          화면/visibleFrame 차이 → DockRegion(빈 띠 before/after)   (순수)
        ▼
  DockLayout(region:edge:)  패널 frame·viewport·이음새·전체 크기 계산                  (순수)
        ▼
  AppDelegate               창에 적용(setFrame, viewport, 포털), 모델에 크기·이음새 전달
```

시스템에 닿는 부분(`DockPlacement`, `DockMonitor`, `AppDelegate`)은 얇게 두고, **계산은 Core의 순수 함수**에 둬서 테스트로 검증해요.

## 확장 가이드

### 설정 항목 추가

`AquariumSettings`는 저장값 호환 때문에 항목마다 손볼 곳이 여럿이에요. 빠뜨리면 컴파일은 되는데 저장·복원이 어긋나요.

1. `Settings.swift`: 프로퍼티, `init` 매개변수(기본값 포함)와 대입, `with(...)` 변경 메서드
2. 같은 파일의 `CodingKeys`와 `init(from:)` — `(try? container.decode(...)) ?? defaults.x` 형태로 **예전 저장값에 키가 없어도** 기본값이 채워지게
3. `SettingsPanel.swift`: UI 추가 (`model.update { $0.with(x: ...) }`)
4. 테스트: 기본값, 범위 보정(clamp), 옛 저장값 디코딩 (`CoreTests.swift`의 Settings 테스트 참고)

저장 키(`SettingsStore.key`)는 호환이 깨지는 변경이 아니면 올리지 않아요.

### 알림 방식 추가 (소리, 알림 센터 등)

1. `AquariumEvent`에 사건이 더 필요하면 case를 추가 (`AquariumEvents.swift`)
2. `AquariumEventHandler`를 구현한 타입을 만들어 `AquariumModel(eventHandlers:)`에 넘겨요 (기본은 `[SoundAlert()]`)
3. 모델에서 사건이 일어나는 곳에서 `emit(...)`을 부르면 모든 핸들러가 받아요

어항 배너와 메뉴바 "끝났어요" 문구는 이벤트가 아니라 모델 상태(`bannerUntil`)로 그려져요. 일정 시간 계속 보여야 해서예요.

### 포모도로와 시스템 연동

둘 다 설정에서 끌 수 있어요 (`pomodoroEnabled` 기본 켜짐, `systemLink` 기본 꺼짐). 꺼 두면 어항은 평소 모습 그대로예요.

- **포모도로**: `AquariumModel.pomodoro`(`PomodoroSession?`)가 있으면 진행 중이에요. 단계마다 기존 타이머(`startTimer`)를 다시 걸고, 끝나면 `finishTimer` → `advancePomodoro`가 다음 단계로 넘기며 `.pomodoroPhaseChanged`를 보내요. 일반 타이머를 시작하거나 취소하면 포모도로도 끝나요.
- **시스템 연동**: `advance()`가 2초마다 `systemSampler`(기본 `SystemMonitor().sample`)를 읽고, `Simulation.speedScale`·`waterLevel`과 모델의 `turbidity`를 목표값으로 부드럽게 따라가게 해요. 꺼지면 목표가 평소 값으로 돌아가요. 테스트·스냅샷은 `systemSampler`에 고정값을 주입해요 (`--sys cpu,mem,battery`).
- 스냅샷: `--pomodoro`, `--controls`로 UI를 확인할 수 있어요. (`ImageRenderer`가 AppKit 기반 스위치를 못 그려 금지 표시로 보이는 건 스냅샷 한계예요.)

### Dock 변화에 반응하기

- 새 **계기**(앱 활성화, Space 전환 등)는 `DockMonitor.start()`에 옵저버를 더해요. 모두 `refreshDock()` 하나로 모여요.
- 새 **배치 규칙**(예: 패널 간격, 다른 정렬)은 `DockLayout`에 넣고 `DockLayoutTests`로 검증해요. AppKit 없이 테스트할 수 있어요.
- `refreshDock()`은 0.5초마다 불리니 **같은 값이면 아무것도 하지 않게** 만들어요 (`setFrame(of:_:)`, `setViewport(of:_:portal:)`처럼).

## 테스트 실행

```bash
swift test
```

Xcode 없이 Command Line Tools만 있는 환경에서는 `Testing` 모듈을 못 찾을 수 있어요. 그럴 땐 프레임워크 경로를 직접 알려줘요.

```bash
F=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
swift test -Xswiftc -F -Xswiftc $F -Xlinker -F -Xlinker $F -Xlinker -rpath -Xlinker $F
```

참고: Command Line Tools에서는 한 파일에서 `Testing`과 `Foundation`을 같이 import하면 빌드가 깨져요. Foundation 타입이 필요한 테스트 보조 코드는 `FoundationSupport.swift`에 둬요.
