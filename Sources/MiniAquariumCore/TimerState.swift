import Foundation

/// 타이머는 종료 시각을 고정해 두고 벽시계로 계산한다.
/// 물고기 수/종류는 연출일 뿐 실제 시간에 영향을 주지 않는다.
public struct TimerState: Equatable {
    public let start: Date
    public let end: Date

    public init(start: Date, duration: TimeInterval) {
        self.start = start
        self.end = start.addingTimeInterval(duration)
    }

    /// 오늘(이미 지났으면 내일) 하루 중 `minuteOfDay`분이 되는 순간까지의 타이머.
    public static func until(minuteOfDay: Int, from now: Date, calendar: Calendar = .current) -> TimerState {
        var parts = calendar.dateComponents([.year, .month, .day], from: now)
        parts.hour = minuteOfDay / 60
        parts.minute = minuteOfDay % 60
        parts.second = 0
        let today = calendar.date(from: parts) ?? now
        let target = today > now ? today : (calendar.date(byAdding: .day, value: 1, to: today) ?? today)
        return TimerState(start: now, duration: target.timeIntervalSince(now))
    }

    public var duration: TimeInterval { end.timeIntervalSince(start) }

    public func remaining(at now: Date) -> TimeInterval {
        max(0, end.timeIntervalSince(now))
    }

    /// 남은 비율 1 → 0
    public func ratio(at now: Date) -> Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, remaining(at: now) / duration))
    }

    public func isFinished(at now: Date) -> Bool { now >= end }

    /// 남은 초를 올림해 "MM:SS" 또는 "H:MM:SS"로 표시한다.
    public static func format(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds).rounded(.up))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }
}
