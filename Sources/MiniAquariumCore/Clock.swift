import Foundation

/// 어항 모드: 화면에 계속 떠 있거나, 메뉴바 아이콘을 클릭하면 열린다.
public enum DisplayMode: String, Codable, CaseIterable {
    case floating, menuBar

    public var title: String {
        switch self {
        case .floating: return tr("항상 화면에 떠 있기", "Always on screen")
        case .menuBar: return tr("메뉴바에서만 (클릭하면 어항)", "Menu bar only (click to open)")
        }
    }
}
