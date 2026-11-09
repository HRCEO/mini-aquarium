import CoreGraphics

/// 물고기와 소품(장식)의 크기. 어항 크기와는 따로 고른다.
public enum ObjectSize: String, Codable, CaseIterable, Sendable {
    case tiny, small, normal, large

    public var title: String {
        switch self {
        case .tiny: return "아주 작게"
        case .small: return "작게"
        case .normal: return "보통"
        case .large: return "크게"
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
