import CoreGraphics
import Foundation

/// 어항 전체의 가로/세로 비율. Dock 옆 빈 공간처럼 길쭉한 자리에 맞출 수 있다.
public enum TankLayout: String, Codable, CaseIterable {
    case standard, wide, slim

    public var title: String {
        switch self {
        case .standard: return "기본"
        case .wide: return "가로로 길게"
        case .slim: return "세로로 길게"
        }
    }

    public var shortTitle: String {
        switch self {
        case .standard: return "기본"
        case .wide: return "가로"
        case .slim: return "세로"
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

/// 시간 띠의 위치/크기. 비율만큼 줄어든다.
public struct NibbleZone {
    public let bar: CGRect
    public let isVertical: Bool

    public init(bar: CGRect, isVertical: Bool) {
        self.bar = bar
        self.isVertical = isVertical
    }

    public static func make(shape: TankShape, layout: TankLayout, in rect: CGRect, ratio: Double) -> NibbleZone {
        guard layout.isBarVertical else {
            return NibbleZone(bar: shape.stripRect(in: rect, ratio: ratio), isVertical: false)
        }
        let top = shape.headerY(in: rect) + 34
        let maxHeight = max(rect.maxY - 46 - top, 40)
        let clamped = CGFloat(min(max(ratio, 0), 1))
        return NibbleZone(
            bar: CGRect(x: rect.midX - 6, y: top, width: 12, height: maxHeight * clamped),
            isVertical: true
        )
    }

    /// 물고기가 띠를 갉아먹을 자리. 첫 마리만 끝(0)을 맡고, 나머지는 한쪽 면(1)·반대쪽 면(2)에 번갈아 앉는다.
    public struct Spot {
        public let center: CGPoint
        public let bite: CGPoint
        public let tilt: Double
        public let facesLeft: Bool
    }

    public func spot(index: Int, size: CGFloat, phase: Double, time: Double) -> Spot {
        let side = index == 0 ? 0 : 1 + (index - 1) % 2
        let leftward = (index / 2) % 2 == 1
        // 물고기마다 다른 속도로 띠 전체를 천천히 오가며 갉는다 (한쪽에 몰리지 않게)
        let pace = 0.07 + 0.05 * Self.fraction(Double(index) * 3.7 + 0.9)
        let sweep = 0.5 + 0.5 * sin(time * pace + phase + Double(index) * 2.1)
        let f = CGFloat(0.06 + 0.9 * sweep)
        let r = bar
        let sx: CGFloat = leftward ? 1 : -1   // 몸이 코에서 얼마나 떨어져 있는지의 부호

        if !isVertical {
            switch side {
            case 0:
                let bite = CGPoint(x: r.maxX, y: r.midY)
                return Spot(center: CGPoint(x: bite.x + size * 0.5, y: bite.y), bite: bite, tilt: 0, facesLeft: true)
            case 1:
                let bite = CGPoint(x: r.minX + r.width * f, y: r.minY)
                return Spot(center: CGPoint(x: bite.x + sx * size * 0.33, y: bite.y - size * 0.38), bite: bite, tilt: 0.85, facesLeft: leftward)
            default:
                let bite = CGPoint(x: r.minX + r.width * f, y: r.maxY)
                return Spot(center: CGPoint(x: bite.x + sx * size * 0.33, y: bite.y + size * 0.38), bite: bite, tilt: -0.85, facesLeft: leftward)
            }
        }
        switch side {
        case 0:
            let bite = CGPoint(x: r.midX, y: r.maxY)
            return Spot(center: CGPoint(x: bite.x, y: bite.y + size * 0.5), bite: bite, tilt: -1.35, facesLeft: false)
        case 1:
            let bite = CGPoint(x: r.minX, y: r.minY + r.height * f)
            return Spot(center: CGPoint(x: bite.x - size * 0.5, y: bite.y), bite: bite, tilt: 0, facesLeft: false)
        default:
            let bite = CGPoint(x: r.maxX, y: r.minY + r.height * f)
            return Spot(center: CGPoint(x: bite.x + size * 0.5, y: bite.y), bite: bite, tilt: 0, facesLeft: true)
        }
    }

    private static func fraction(_ seed: Double) -> Double {
        let value = sin(seed * 12.9898) * 43758.5453
        return value - value.rounded(.down)
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
