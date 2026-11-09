import CoreGraphics

/// Dock 옆의 빈 자리. 좌표는 AppKit(원점 왼쪽 아래) 기준.
/// Dock 아이콘 줄(알약)을 사이에 두고 `before`(세로: 위쪽 / 가로: 왼쪽)와 `after`(아래쪽 / 오른쪽) 두 빈 띠가 있다.
public struct DockRegion: Equatable {
    public enum Side: Equatable { case left, right, bottom }
    public let side: Side
    public let before: CGRect?
    public let after: CGRect?
    public var isVertical: Bool { side != .bottom }

    /// 선택한 쪽의 띠들 (before → after 순서). 선택한 쪽에 자리가 없으면 남은 쪽을 쓴다.
    public func strips(for edge: DockEdge) -> [CGRect] {
        switch edge {
        case .before: return [before ?? after].compactMap { $0 }
        case .after: return [after ?? before].compactMap { $0 }
        case .both: return [before, after].compactMap { $0 }
        }
    }
}

/// Dock 기준으로 어항을 둘 쪽.
public enum DockEdge: String, Codable, CaseIterable, Sendable {
    case before, after, both

    public func title(vertical: Bool) -> String {
        switch self {
        case .before: return vertical ? tr("위쪽", "Top") : tr("왼쪽", "Left")
        case .after: return vertical ? tr("아래쪽", "Bottom") : tr("오른쪽", "Right")
        case .both: return tr("양쪽", "Both sides")
        }
    }
}

public enum DockFit {
    static let minimumInset: CGFloat = 20
    static let minimumLength: CGFloat = 120
    public static let margin: CGFloat = 14

    /// `screen`과 `visible`(Dock/메뉴바 제외)의 차이로 Dock 방향과 두께를 알아낸다.
    /// 아이콘 줄의 실제 영역(`measuredPill`)을 알면 그것을, 모르면 아이콘 개수로 어림해 가운데 있다고 본다.
    /// Dock이 숨겨져 있거나 자리가 없으면 nil.
    public static func region(
        screen: CGRect, visible: CGRect, dockItems: Int, tile: CGFloat, measuredPill: CGRect? = nil, gap: CGFloat = margin
    ) -> DockRegion? {
        let right = screen.maxX - visible.maxX
        let left = visible.minX - screen.minX
        let bottom = visible.minY - screen.minY
        // 아이콘 하나가 타일 크기만큼 차지하고, 구분선과 알약 안쪽 여백이 더해진다. (이 Dock에서 실측한 값에 맞춤)
        let estimated = CGFloat(dockItems) * tile + 30

        if max(right, left) >= max(bottom, minimumInset) {
            let isRight = right >= left
            let inset = isRight ? right : left
            let x = isRight ? visible.maxX : screen.minX
            let low = measuredPill?.minY ?? (visible.midY - estimated / 2)
            let high = measuredPill?.maxY ?? (visible.midY + estimated / 2)
            let before = strip(CGRect(x: x, y: high + gap, width: inset, height: visible.maxY - high - gap))
            let after = strip(CGRect(x: x, y: visible.minY, width: inset, height: low - gap - visible.minY))
            guard before != nil || after != nil else { return nil }
            return DockRegion(side: isRight ? .right : .left, before: before, after: after)
        }
        guard bottom >= minimumInset else { return nil }
        let low = measuredPill?.minX ?? (visible.midX - estimated / 2)
        let high = measuredPill?.maxX ?? (visible.midX + estimated / 2)
        let before = strip(CGRect(x: visible.minX, y: screen.minY, width: low - gap - visible.minX, height: bottom))
        let after = strip(CGRect(x: high + gap, y: screen.minY, width: visible.maxX - high - gap, height: bottom))
        guard before != nil || after != nil else { return nil }
        return DockRegion(side: .bottom, before: before, after: after)
    }

    private static func strip(_ rect: CGRect) -> CGRect? {
        max(rect.width, rect.height) >= minimumLength && min(rect.width, rect.height) > 0 ? rect : nil
    }
}
