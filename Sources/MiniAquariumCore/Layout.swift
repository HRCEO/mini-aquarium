import CoreGraphics
import Foundation

/// 어항 전체의 가로/세로 비율. Dock 옆 빈 공간처럼 길쭉한 자리에 맞출 수 있다.
public enum TankLayout: String, Codable, CaseIterable {
    case standard, wide, slim

    public var title: String {
        switch self {
        case .standard: return tr("기본", "Default")
        case .wide: return tr("가로로 길게", "Wide")
        case .slim: return tr("세로로 길게", "Tall")
        }
    }

    public var shortTitle: String {
        switch self {
        case .standard: return tr("기본", "Default")
        case .wide: return tr("가로", "Wide")
        case .slim: return tr("세로", "Tall")
        }
    }

    /// 배율 1.0일 때의 논리 크기
    public var logicalSize: CGSize {
        switch self {
        case .standard: return CGSize(width: 300, height: 260)
        case .wide: return CGSize(width: 480, height: 170)
        case .slim: return CGSize(width: 150, height: 440)
        }
    }

    /// 시간 띠가 세로로 놓이는가 (위가 고정, 아래 끝이 줄어든다)
    public var isBarVertical: Bool { self == .slim }
}

/// 시간 띠의 위치/크기. 띠는 처음 길이 그대로 놓이고, 칸 단위로 물고기에게 갉아먹힌다.
public struct NibbleZone {
    /// 처음(가득 찼을 때) 띠 전체의 영역
    public let bar: CGRect
    public let isVertical: Bool
    public let cellCount: Int

    public init(bar: CGRect, isVertical: Bool, cellCount: Int = BitePattern.defaultCellCount) {
        self.bar = bar
        self.isVertical = isVertical
        self.cellCount = max(cellCount, 1)
    }

    /// 이보다 낮은 어항은 글씨와 띠를 한 줄 + 한 줄로 압축해 놓는다.
    public static let compactHeight: CGFloat = 100
    /// 납작한 어항에서 양 끝 둥근 모서리를 피하는 여백, 글씨 자리, 띠 두께
    public static let compactEdgePadding: CGFloat = 28
    public static let compactTextWidth: CGFloat = 138
    public static let compactBarHeight: CGFloat = 10

    public static func make(shape: TankShape, layout: TankLayout, in rect: CGRect) -> NibbleZone {
        if !layout.isBarVertical, rect.height < compactHeight {
            // 납작한 Dock 어항: 오른쪽 끝에 글씨, 나머지 전체 길이(이어 붙인 양쪽 어항 모두)는 먹이 띠 한 줄.
            let left = rect.minX + compactEdgePadding
            let right = rect.maxX - compactEdgePadding - compactTextWidth
            return NibbleZone(bar: CGRect(x: left, y: rect.midY - compactBarHeight / 2, width: max(right - left, 40), height: compactBarHeight), isVertical: false)
        }
        guard layout.isBarVertical else {
            return NibbleZone(bar: shape.stripRect(in: rect, ratio: 1), isVertical: false)
        }
        let top = shape.headerY(in: rect) + 34
        let maxHeight = max(rect.maxY - 46 - top, 40)
        return NibbleZone(bar: CGRect(x: rect.midX - 6, y: top, width: 12, height: maxHeight), isVertical: true)
    }

    /// 띠를 따라 잰 한 칸의 길이
    public var cellLength: CGFloat { (isVertical ? bar.height : bar.width) / CGFloat(cellCount) }

    public func cellRect(_ cell: Int) -> CGRect {
        let offset = CGFloat(cell) * cellLength
        return isVertical
            ? CGRect(x: bar.minX, y: bar.minY + offset, width: bar.width, height: cellLength)
            : CGRect(x: bar.minX + offset, y: bar.minY, width: cellLength, height: bar.height)
    }

    /// 물고기가 띠를 갉아먹을 자리.
    public struct Spot {
        public let center: CGPoint
        public let bite: CGPoint
        public let tilt: Double
        public let facesLeft: Bool
    }

    /// `cell`을 갉는 `index`번 물고기의 자리. 물고기마다 띠의 위/아래(세로면 좌/우) 면을 번갈아 쓴다.
    public func spot(cell: Int, index: Int, size: CGFloat) -> Spot {
        let rect = cellRect(cell)
        let upper = index % 2 == 0
        let leftward = (index / 2) % 2 == 1
        let sx: CGFloat = leftward ? 1 : -1   // 몸이 코에서 얼마나 떨어져 있는지의 부호

        if !isVertical {
            let bite = CGPoint(x: rect.midX, y: upper ? bar.minY : bar.maxY)
            let dy = size * 0.38 * (upper ? -1 : 1)
            return Spot(center: CGPoint(x: bite.x + sx * size * 0.33, y: bite.y + dy), bite: bite, tilt: upper ? 0.85 : -0.85, facesLeft: leftward)
        }
        let bite = CGPoint(x: upper ? bar.minX : bar.maxX, y: rect.midY)
        return Spot(center: CGPoint(x: bite.x + (upper ? -1 : 1) * size * 0.5, y: bite.y), bite: bite, tilt: 0, facesLeft: !upper)
    }
}

/// 물고기가 궁금해서 찾아가는 소품 위치.
public struct Attraction {
    public let decor: Decor
    public let pos: CGPoint

    public init(decor: Decor, pos: CGPoint) {
        self.decor = decor
        self.pos = pos
    }

    /// 들어가서 숨는 소품인가
    public var isEnterable: Bool { decor == .cave || decor == .castle }
}
