import CoreGraphics

/// 물고기와 소품(장식)의 크기. 어항 크기와는 따로 고른다.
public enum ObjectSize: String, Codable, CaseIterable, Sendable {
    case tiny, small, normal, large

    public var title: String {
        switch self {
        case .tiny: return tr("아주 작게", "Tiny")
        case .small: return tr("작게", "Small")
        case .normal: return tr("보통", "Normal")
        case .large: return tr("크게", "Large")
        }
    }

    /// 물고기 몸 길이에 곱하는 배율.
    public var fishScale: CGFloat {
        switch self {
        case .tiny: return 0.45
        case .small: return 0.6
        case .normal: return 0.8
        case .large: return 1.0
        }
    }

    /// 소품 그림에 곱하는 배율 (`Decor.displayScale`에 더 곱한다).
    public var decorScale: CGFloat {
        switch self {
        case .tiny: return 0.5
        case .small: return 0.65
        case .normal: return 0.8
        case .large: return 1.0
        }
    }
}
