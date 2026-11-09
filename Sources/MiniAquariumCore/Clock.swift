import Foundation

/// 어항 모드: 화면에 계속 떠 있거나, 메뉴바 시계를 클릭하면 열린다.
public enum DisplayMode: String, Codable, CaseIterable {
    case floating, menuBar

    public var title: String {
        switch self {
        case .floating: return "항상 화면에 떠 있기"
        case .menuBar: return "메뉴바 시계 (클릭하면 어항)"
        }
    }
}

/// 시계 표시 형식.
public struct ClockStyle: Codable, Equatable {
    public var showSeconds: Bool
    public var use24Hour: Bool
    public var showDate: Bool

    public init(showSeconds: Bool = true, use24Hour: Bool = false, showDate: Bool = true) {
        self.showSeconds = showSeconds
        self.use24Hour = use24Hour
        self.showDate = showDate
    }

    /// 시계가 바뀌는 최소 간격(초). 초 표시가 없으면 갱신을 아낄 수 있다.
    public var refreshInterval: TimeInterval { showSeconds ? 1 : 15 }
}

public enum ClockFormat {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var formatters: [String: DateFormatter] = [:]

    public static func time(_ date: Date, style: ClockStyle, timeZone: TimeZone = .current) -> String {
        let pattern: String
        switch (style.use24Hour, style.showSeconds) {
        case (true, true): pattern = "HH:mm:ss"
        case (true, false): pattern = "HH:mm"
        case (false, true): pattern = "a h:mm:ss"
        case (false, false): pattern = "a h:mm"
        }
        return formatter(pattern, timeZone).string(from: date)
    }

    public static func day(_ date: Date, timeZone: TimeZone = .current) -> String {
        formatter("M월 d일 (E)", timeZone).string(from: date)
    }

    /// 메뉴바에 보이는 문장. 예: "11월 9일 (월) 오전 9:33:16"
    public static func menuBarText(_ date: Date, style: ClockStyle, timeZone: TimeZone = .current) -> String {
        let clock = time(date, style: style, timeZone: timeZone)
        return style.showDate ? "\(day(date, timeZone: timeZone)) \(clock)" : clock
    }

    private static func formatter(_ pattern: String, _ timeZone: TimeZone) -> DateFormatter {
        let key = "\(pattern)|\(timeZone.identifier)"
        lock.lock()
        defer { lock.unlock() }
        if let cached = formatters[key] { return cached }
        let created = DateFormatter()
        created.locale = Locale(identifier: "ko_KR")
        created.timeZone = timeZone
        created.dateFormat = pattern
        formatters[key] = created
        return created
    }
}
