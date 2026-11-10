import Foundation
@testable import MiniAquariumCore

// 이 파일은 일부러 Testing을 import하지 않는다.
// Command Line Tools 환경에서는 `Testing` + `Foundation`을 같은 파일에서 import하면
// 깨진 `_Testing_Foundation` 오버레이를 찾다가 빌드가 실패한다.
// Foundation 타입(Date, UserDefaults)이 필요한 부분을 여기로 분리한다.

/// 시작 시각이 고정된 타이머와, "시작 후 N초" 기준 조회 헬퍼.
struct FixedTimer {
    let state: TimerState
    private let origin = Date(timeIntervalSince1970: 1_000)

    init(duration: Double) {
        state = TimerState(start: origin, duration: duration)
    }

    func remaining(after seconds: Double) -> Double {
        state.remaining(at: origin.addingTimeInterval(seconds))
    }

    func ratio(after seconds: Double) -> Double {
        state.ratio(at: origin.addingTimeInterval(seconds))
    }

    func isFinished(after seconds: Double) -> Bool {
        state.isFinished(at: origin.addingTimeInterval(seconds))
    }

    /// 10:00 기준으로 `offset`분 뒤 시각까지 타이머가 기다리는 초.
    static func waitSeconds(offsetMinutes offset: Int) -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let now = sampleDate(hour: 10, minute: 0, second: 0)
        let target = ((10 * 60 + offset) % 1440 + 1440) % 1440
        return TimerState.until(minuteOfDay: target, from: now, calendar: calendar).duration
    }

    static let utc = TimeZone(identifier: "UTC") ?? .current

    static func sampleDate(hour: Int, minute: Int, second: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let parts = DateComponents(year: 2026, month: 11, day: 9, hour: hour, minute: minute, second: second)
        return calendar.date(from: parts) ?? Date(timeIntervalSince1970: 0)
    }
}

/// 테스트마다 독립된 UserDefaults. `cleanup()`으로 정리한다.
struct EphemeralDefaults {
    let defaults: UserDefaults
    private let suite = "MiniAquariumTests-\(UUID().uuidString)"

    init?() {
        guard let created = UserDefaults(suiteName: suite) else { return nil }
        defaults = created
    }

    func writeRaw(_ json: String) {
        defaults.set(Data(json.utf8), forKey: SettingsStore.key)
    }

    func cleanup() {
        defaults.removePersistentDomain(forName: suite)
    }
}

/// 저장된 JSON에서 PomodoroPlan을 복원한다. 깨진 값도 그대로 넘겨 디코딩 보정을 검증한다.
func decodePomodoroPlan(_ json: String) -> PomodoroPlan? {
    try? JSONDecoder().decode(PomodoroPlan.self, from: Data(json.utf8))
}
