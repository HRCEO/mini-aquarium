import Foundation

/// 앱 표시 언어. 설정에서 바꿀 수 있고, 처음에는 시스템 언어를 따른다.
public enum Language: String, Codable, CaseIterable, Sendable {
    case ko, en

    public var nativeName: String { self == .ko ? "한국어" : "English" }

    public static var system: Language {
        Locale.preferredLanguages.first?.hasPrefix("ko") == true ? .ko : .en
    }
}

public enum L10n {
    /// 화면을 그리기 전에 모델이 갱신한다 (메인 스레드에서만 읽고 쓴다).
    public nonisolated(unsafe) static var current: Language = .system
}

/// 현재 언어에 맞는 문구를 고른다.
public func tr(_ ko: String, _ en: String) -> String {
    L10n.current == .ko ? ko : en
}
