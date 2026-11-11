import CoreGraphics
import Foundation

/// 어항 모양과 그에 따른 기하 계산.
public enum TankShape: String, Codable, CaseIterable {
    case rounded, bowl, tall

    public var title: String {
        switch self {
        case .rounded: return tr("사각 어항", "Square tank")
        case .bowl: return tr("둥근 어항", "Round tank")
        case .tall: return tr("길쭉한 어항", "Tall tank")
        }
    }

    public var isEllipse: Bool { self == .bowl }

    public var cornerRadius: CGFloat { self == .tall ? 44 : 24 }

    /// 창 크기 안에서 어항이 차지하는 영역.
    public func rect(in size: CGSize, inset: CGFloat = 10) -> CGRect {
        let full = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
        switch self {
        case .rounded, .bowl:
            return full
        case .tall:
            let width = full.width * 0.62
            return CGRect(x: full.midX - width / 2, y: full.minY, width: width, height: full.height)
        }
    }

    /// 점을 어항 내부로 되돌린다. 타원형은 타원 경계로 투영한다.
    public func clamp(_ point: CGPoint, in rect: CGRect, margin: CGFloat) -> CGPoint {
        let inner = rect.insetBy(dx: margin, dy: margin)
        guard isEllipse else {
            return CGPoint(
                x: min(max(point.x, inner.minX), inner.maxX),
                y: min(max(point.y, inner.minY), inner.maxY)
            )
        }
        let a = inner.width / 2, b = inner.height / 2
        guard a > 0, b > 0 else { return CGPoint(x: inner.midX, y: inner.midY) }
        let dx = (point.x - inner.midX) / a, dy = (point.y - inner.midY) / b
        let d = hypot(dx, dy)
        if d <= 1 { return point }
        return CGPoint(x: inner.midX + dx / d * a, y: inner.midY + dy / d * b)
    }

    /// 바닥 위 위치(0...1)를 가로 좌표로 바꾼다. 타원은 가장자리가 좁아 안쪽으로 모은다.
    public func floorX(_ slot: CGFloat, in rect: CGRect) -> CGFloat {
        rect.minX + rect.width * (isEllipse ? 0.22 + slot * 0.56 : slot)
    }

    /// 가로 좌표 `x`에서 발이 닿는 높이. 타원은 가장자리로 갈수록 바닥이 올라간다.
    public func floorY(atX x: CGFloat, in rect: CGRect, lift: CGFloat) -> CGFloat {
        let base = rect.maxY - lift
        guard isEllipse, rect.width > 0 else { return base }
        let edge = min(max((x - rect.midX) / (rect.width / 2), -1), 1)
        return base - rect.height / 2 * (1 - (1 - edge * edge).squareRoot())
    }

    /// 시계/타이머 글자의 세로 기준선.
    public func headerY(in rect: CGRect) -> CGFloat {
        isEllipse ? rect.minY + rect.height * 0.24 : rect.minY + 30
    }

    /// 타이머 모드에서 물고기가 갉아먹는 "시간 띠". 비율만큼 왼쪽 기준으로 줄어든다.
    public func stripRect(in rect: CGRect, ratio: Double) -> CGRect {
        let maxWidth = isEllipse ? rect.width * 0.5 : rect.width - 56
        let clamped = CGFloat(min(max(ratio, 0), 1))
        return CGRect(
            x: rect.midX - maxWidth / 2,
            y: headerY(in: rect) + 34,
            width: maxWidth * clamped,
            height: 12
        )
    }
}
