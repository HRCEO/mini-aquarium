import CoreGraphics
import Foundation

/// 어항 전체 크기 배율. 기준 크기(300×260)에 곱해 창 크기를 정한다.
public enum TankSize: String, Codable, CaseIterable {
    case small, medium, large, huge

    public var title: String {
        switch self {
        case .small: return tr("작게", "Small")
        case .medium: return tr("보통", "Normal")
        case .large: return tr("크게", "Large")
        case .huge: return tr("아주 크게", "Huge")
        }
    }

    public var scale: CGFloat {
        switch self {
        case .small: return 0.7
        case .medium: return 1.0
        case .large: return 1.4
        case .huge: return 1.9
        }
    }

    public func windowSize(base: CGSize) -> CGSize {
        CGSize(width: (base.width * scale).rounded(), height: (base.height * scale).rounded())
    }
}
