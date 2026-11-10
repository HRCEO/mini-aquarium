import CoreGraphics

/// `DockRegion`(Dock 옆 빈 띠들)과 사용자가 고른 `DockEdge`로, 어항 패널들을 어떻게 놓을지 계산한다.
///
/// 순수 계산이라 AppKit 없이 테스트할 수 있다. 앱은 이 결과를 그대로 창에 적용만 한다.
/// - 띠가 하나면 패널 하나가 그 띠를 채운다.
/// - 띠가 둘('양쪽')이면 Dock 너머로 이어진 긴 어항 하나(`world`)가 되고,
///   패널마다 그 일부(`viewport`)만 보여준다. 두 띠가 만나는 지점이 `seam`이다.
public struct DockLayout: Equatable {
    /// 화면에 놓을 패널 하나. `frame`은 화면 좌표(AppKit), `viewport`는 `world` 안에서 이 패널이 보여줄 영역.
    public struct Panel: Equatable {
        public let frame: CGRect
        public let viewport: CGRect
    }

    /// 어항 전체(논리) 크기. 띠가 둘이면 두 띠의 길이를 더한 크기.
    public let world: CGSize
    /// 두 띠가 이어지는 지점. `world`의 긴 축 기준 위치이고, 띠가 하나면 nil.
    public let seam: CGFloat?
    public let isVertical: Bool
    public let panels: [Panel]

    /// 고른 쪽에 놓을 띠가 하나도 없으면 nil.
    public init?(region: DockRegion, edge: DockEdge) {
        let strips = region.strips(for: edge)
        guard !strips.isEmpty else { return nil }
        let vertical = region.isVertical

        func length(_ size: CGSize) -> CGFloat { vertical ? size.height : size.width }
        func along(_ offset: CGFloat) -> CGPoint { vertical ? CGPoint(x: 0, y: offset) : CGPoint(x: offset, y: 0) }

        // 모든 패널이 같은 두께를 갖도록 가장 얇은 띠에 맞춘다.
        let thickness = strips.map { vertical ? $0.width : $0.height }.min() ?? 0
        let sizes = strips.map { strip in
            vertical ? CGSize(width: thickness, height: strip.height) : CGSize(width: strip.width, height: thickness)
        }
        let total = sizes.reduce(0) { $0 + length($1) }

        var offset: CGFloat = 0
        var panels: [Panel] = []
        for (strip, size) in zip(strips, sizes) {
            let isBefore = strip == region.before
            let origin: CGPoint
            if vertical {
                // 아이콘 줄 반대쪽(화면 가장자리 쪽)으로 붙인다.
                origin = CGPoint(x: strip.minX, y: isBefore ? strip.maxY - size.height : strip.minY)
            } else {
                origin = CGPoint(x: isBefore ? strip.minX : strip.maxX - size.width, y: strip.minY)
            }
            panels.append(Panel(frame: CGRect(origin: origin, size: size), viewport: CGRect(origin: along(offset), size: size)))
            offset += length(size)
        }

        self.world = vertical ? CGSize(width: thickness, height: total) : CGSize(width: total, height: thickness)
        self.seam = sizes.count > 1 ? length(sizes[0]) : nil
        self.isVertical = vertical
        self.panels = panels
    }
}
