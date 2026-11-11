import Foundation

/// 어항 바닥을 걸어 다니는 작은 생물. 물고기와 달리 헤엄치지 않고, 소품 위에 올라가 쉬기도 한다.
public enum CritterKind: String, Codable, CaseIterable, Sendable {
    case crab

    public var title: String {
        switch self {
        case .crab: return tr("게", "Crab")
        }
    }

    /// 걷는 속도 (바닥 전체 길이 대비 비율/초)
    var walkSpeed: Double { 0.06 }

    /// 한 번 걷고 나서 쉬는 시간 (초)
    var restRange: ClosedRange<Double> { 2.5...7 }

    /// 한 번에 걷는 거리 (바닥 전체 길이 대비 비율)
    var stepRange: ClosedRange<Double> { 0.08...0.3 }

    /// 다음 걸음에 소품 위로 올라가려 할 확률
    var perchChance: Double { 0.45 }

    /// 발이 닿는 높이: 모래 바닥 아래쪽에서 얼마나 위인지 (pt)
    public var floorLift: CGFloat { 6 }
}

/// 걸어서 올라설 수 있는 소품 윗면. 가장자리는 완만한 언덕처럼 내려간다.
public struct Perch: Equatable, Sendable {
    public let slot: Double        // 중심 가로 위치 (0...1)
    public let halfWidth: Double   // slot 단위 반폭
    public let height: Double      // 바닥에서 올라서는 높이 (pt)

    public init(slot: Double, halfWidth: Double, height: Double) {
        self.slot = slot
        self.halfWidth = halfWidth
        self.height = height
    }

    /// 가로 위치 `x`에서 올라서는 높이.
    public func lift(at x: Double) -> Double {
        let distance = abs(x - slot)
        guard distance < halfWidth else { return 0 }
        let flat = halfWidth * 0.55
        if distance <= flat { return height }
        let t = (distance - flat) / (halfWidth - flat)
        return height * 0.5 * (1 + cos(t * .pi))
    }

    /// 소품 목록에서 올라설 수 있는 것만 골라 발판으로 만든다. `scale`은 소품 그림 배율.
    public static func make(decors: [Decor], scale: CGFloat, rect: CGRect, shape: TankShape) -> [Perch] {
        let span = Double(shape.floorX(1, in: rect) - shape.floorX(0, in: rect))
        guard span > 0 else { return [] }
        let scale = Double(scale)
        return decors.compactMap { decor in
            guard let top = decor.perchProfile else { return nil }
            return Perch(
                slot: Double(decor.slot) + Double(top.offset) * scale / span,
                halfWidth: Double(top.halfWidth) * scale / span,
                height: Double(top.height) * scale + footDrop
            )
        }
    }

    /// 소품 바닥이 게 발 높이보다 이만큼 위라서, 올라선 높이에 더해 준다 (pt).
    private static let footDrop = 3.0
}

/// 바닥 위를 걷다 쉬다 하는 생물 한 마리.
public struct Critter: Identifiable {
    /// 걸어 다니는 바닥 범위 (0 = 왼쪽 끝, 1 = 오른쪽 끝). 벽에 붙지 않게 안쪽으로 둔다.
    public static let slotRange: ClosedRange<Double> = 0.06...0.94

    public let id = UUID()
    public let kind: CritterKind
    /// 바닥 위 가로 위치 (0...1)
    public private(set) var slot: Double
    /// 올라선 소품 윗면까지의 높이 (pt). 바닥이면 0.
    public private(set) var altitude: Double = 0
    public private(set) var facingRight = Bool.random()
    /// 지금 걷고 있는가 (쉬는 중이면 false)
    public private(set) var isMoving = false
    /// 걷는 동안만 흐르는 시간. 다리 애니메이션의 박자로 쓴다.
    public private(set) var gait: Double = 0
    /// 쉬는 동안의 몸짓이 개체마다 어긋나도록 하는 고정 위상
    public let phase = Double.random(in: 0..<(2 * .pi))
    private var target: Double
    private var restLeft: Double

    public init(kind: CritterKind, slot: Double = .random(in: Critter.slotRange)) {
        let start = Self.clamped(slot)
        self.kind = kind
        self.slot = start
        self.target = start
        self.restLeft = .random(in: 0...kind.restRange.upperBound)   // 여럿이 동시에 움직이지 않게
    }

    public mutating func step(_ dt: Double, perches: [Perch] = []) {
        guard dt > 0 else { return }
        if isMoving {
            walk(dt)
        } else {
            restLeft -= dt
            if restLeft <= 0 { chooseTarget(perches) }
        }
        // 지나가는 소품의 윗면을 따라 오르내린다.
        let ground = perches.map { $0.lift(at: slot) }.max() ?? 0
        altitude += (ground - altitude) * min(1, dt * 10)
    }

    private mutating func walk(_ dt: Double) {
        let remaining = target - slot
        let travel = kind.walkSpeed * dt
        gait += dt
        if abs(remaining) <= travel {
            slot = target
            isMoving = false
            restLeft = .random(in: kind.restRange)
        } else {
            slot += remaining > 0 ? travel : -travel
        }
    }

    private mutating func chooseTarget(_ perches: [Perch]) {
        if let perch = perches.randomElement(), Double.random(in: 0..<1) < kind.perchChance {
            go(to: Self.clamped(perch.slot + .random(in: -0.3...0.3) * perch.halfWidth))
            return
        }
        let distance = Double.random(in: kind.stepRange)
        var direction: Double = Bool.random() ? 1 : -1
        if !Self.slotRange.contains(slot + direction * distance) { direction = -direction }   // 벽이면 돌아선다
        go(to: Self.clamped(slot + direction * distance))
    }

    private mutating func go(to spot: Double) {
        target = spot
        if abs(spot - slot) > 0.001 { facingRight = spot > slot }
        isMoving = true
    }

    private static func clamped(_ slot: Double) -> Double {
        min(max(slot, slotRange.lowerBound), slotRange.upperBound)
    }
}
