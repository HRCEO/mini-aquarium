import Foundation

/// 포모도로의 단계.
public enum PomodoroPhase: String, Codable, Equatable {
    case focus, shortBreak, longBreak

    public var isBreak: Bool { self != .focus }
}

/// 포모도로 시간 구성. 값은 항상 허용 범위로 보정된다.
public struct PomodoroPlan: Codable, Equatable {
    public static let focusRange = 1...180
    public static let breakRange = 1...60
    public static let cyclesRange = 2...8

    public let focusMinutes: Int
    public let shortBreakMinutes: Int
    public let longBreakMinutes: Int
    /// 집중을 몇 번 마치면 긴 휴식인가.
    public let cyclesBeforeLongBreak: Int

    public init(focusMinutes: Int = 25, shortBreakMinutes: Int = 5, longBreakMinutes: Int = 15, cyclesBeforeLongBreak: Int = 4) {
        self.focusMinutes = Self.focusRange.clamped(focusMinutes)
        self.shortBreakMinutes = Self.breakRange.clamped(shortBreakMinutes)
        self.longBreakMinutes = Self.breakRange.clamped(longBreakMinutes)
        self.cyclesBeforeLongBreak = Self.cyclesRange.clamped(cyclesBeforeLongBreak)
    }

    private enum CodingKeys: String, CodingKey {
        case focusMinutes, shortBreakMinutes, longBreakMinutes, cyclesBeforeLongBreak
    }

    /// 저장값이 깨졌거나 손으로 고쳐도 범위 보정(0으로 나누기 방지 포함)을 거치도록 한다.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = PomodoroPlan()
        self.init(
            focusMinutes: (try? c.decode(Int.self, forKey: .focusMinutes)) ?? d.focusMinutes,
            shortBreakMinutes: (try? c.decode(Int.self, forKey: .shortBreakMinutes)) ?? d.shortBreakMinutes,
            longBreakMinutes: (try? c.decode(Int.self, forKey: .longBreakMinutes)) ?? d.longBreakMinutes,
            cyclesBeforeLongBreak: (try? c.decode(Int.self, forKey: .cyclesBeforeLongBreak)) ?? d.cyclesBeforeLongBreak
        )
    }

    public func with(focus minutes: Int) -> PomodoroPlan {
        PomodoroPlan(focusMinutes: minutes, shortBreakMinutes: shortBreakMinutes, longBreakMinutes: longBreakMinutes, cyclesBeforeLongBreak: cyclesBeforeLongBreak)
    }

    public func with(shortBreak minutes: Int) -> PomodoroPlan {
        PomodoroPlan(focusMinutes: focusMinutes, shortBreakMinutes: minutes, longBreakMinutes: longBreakMinutes, cyclesBeforeLongBreak: cyclesBeforeLongBreak)
    }

    public func with(longBreak minutes: Int) -> PomodoroPlan {
        PomodoroPlan(focusMinutes: focusMinutes, shortBreakMinutes: shortBreakMinutes, longBreakMinutes: minutes, cyclesBeforeLongBreak: cyclesBeforeLongBreak)
    }

    public func with(cycles: Int) -> PomodoroPlan {
        PomodoroPlan(focusMinutes: focusMinutes, shortBreakMinutes: shortBreakMinutes, longBreakMinutes: longBreakMinutes, cyclesBeforeLongBreak: cycles)
    }

    public func minutes(for phase: PomodoroPhase) -> Int {
        switch phase {
        case .focus: return focusMinutes
        case .shortBreak: return shortBreakMinutes
        case .longBreak: return longBreakMinutes
        }
    }

    public func duration(of phase: PomodoroPhase) -> TimeInterval { TimeInterval(minutes(for: phase) * 60) }
}

/// 진행 중인 포모도로. 단계가 끝날 때마다 `advanced(plan:)`로 다음 상태를 얻는다.
public struct PomodoroSession: Equatable {
    public let phase: PomodoroPhase
    /// 지금까지 끝낸 집중 횟수.
    public let completedFocus: Int

    public init(phase: PomodoroPhase = .focus, completedFocus: Int = 0) {
        self.phase = phase
        self.completedFocus = max(0, completedFocus)
    }

    /// 지금 단계를 마친 뒤의 상태. 집중 → (짧은|긴) 휴식 → 집중 …
    public func advanced(plan: PomodoroPlan) -> PomodoroSession {
        switch phase {
        case .focus:
            let done = completedFocus + 1
            let isLong = done % plan.cyclesBeforeLongBreak == 0
            return PomodoroSession(phase: isLong ? .longBreak : .shortBreak, completedFocus: done)
        case .shortBreak, .longBreak:
            return PomodoroSession(phase: .focus, completedFocus: completedFocus)
        }
    }

    /// 현재 세트(긴 휴식까지)에서 몇 번째 집중인가 (1부터).
    public func focusIndexInSet(plan: PomodoroPlan) -> Int {
        let inSet = completedFocus % plan.cyclesBeforeLongBreak
        return phase == .focus ? inSet + 1 : (inSet == 0 ? plan.cyclesBeforeLongBreak : inSet)
    }
}

private extension ClosedRange where Bound == Int {
    func clamped(_ value: Int) -> Int { Swift.min(Swift.max(value, lowerBound), upperBound) }
}
