import AppKit
import MiniAquariumCore

/// 어항에서 사용자에게 알릴 만한 일.
enum AquariumEvent: Equatable {
    /// 타이머가 끝났다.
    case timerFinished
    /// 포모도로가 다음 단계로 넘어갔다 (값은 새로 시작한 단계).
    case pomodoroPhaseChanged(PomodoroPhase)
}

/// 이벤트가 일어났을 때 무언가를 하는 쪽 (소리, 알림 센터, 화면 번쩍임 …).
///
/// 알림 방식을 새로 추가하려면 이 프로토콜을 구현해서 `AquariumModel(eventHandlers:)`에 넘기면 된다.
/// 모델은 어떤 핸들러가 있는지 알 필요가 없다.
///
/// 참고: 화면에 보이는 "끝났어요" 연출(어항 배너, 메뉴바 문구)은 이벤트가 아니라 모델의 상태(`bannerUntil`)로
/// 그려진다. 일정 시간 동안 계속 보여야 하고 창을 다시 그릴 때마다 필요하기 때문이다.
protocol AquariumEventHandler {
    func handle(_ event: AquariumEvent)
}

/// 타이머가 끝나거나 포모도로 단계가 바뀌면 시스템 효과음을 낸다.
/// 휴식이 시작될 때와 집중이 시작될 때 소리가 달라서 화면을 보지 않아도 구분된다.
struct SoundAlert: AquariumEventHandler {
    var soundName = "Glass"
    var focusStartSoundName = "Ping"

    func handle(_ event: AquariumEvent) {
        switch event {
        case .timerFinished:
            NSSound(named: soundName)?.play()
        case .pomodoroPhaseChanged(let phase):
            NSSound(named: phase.isBreak ? soundName : focusStartSoundName)?.play()
        }
    }
}
