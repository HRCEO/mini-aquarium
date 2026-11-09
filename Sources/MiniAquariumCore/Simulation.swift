import CoreGraphics
import Foundation

public struct Fish: Identifiable {
    public let id = UUID()
    public let species: Species
    public var pos: CGPoint
    public var vel = CGVector.zero
    public var facingLeft = Bool.random()
    public var eatPulse: Double = 0
    public var isNibbling = false
    public var nibbleTilt: Double = 0
    public var visiting: Decor?
    /// 포털을 막 통과한 뒤 잠깐 빨라지는 정도 (1→0)
    public var dash: Double = 0
    var seamSide = 0
    /// 동굴/성 안에 들어가 있는가 (그림을 반투명하게 그린다)
    public var isInside = false
    public let phase = Double.random(in: 0..<(2 * .pi))
    var target: CGPoint
    var retargetIn: Double = 0

    public init(species: Species, pos: CGPoint) {
        self.species = species
        self.pos = pos
        self.target = pos
    }
}

public struct Food {
    public let kind: FoodKind
    public var pos: CGPoint
    public var age: Double = 0
    /// 남은 양 (1 = 그대로, 0 = 다 먹음). 물고기가 갉을수록 줄어든다.
    public var remaining: Double = 1
    /// 그림에 변화를 주기 위한 고정 난수 (0..<1)
    public let seed: Double

    public init(kind: FoodKind, pos: CGPoint, seed: Double = .random(in: 0..<1)) {
        self.kind = kind
        self.pos = pos
        self.seed = seed
    }
}

public struct Crumb {
    public var pos: CGPoint
    public var vel: CGVector
    public var life: Double
}

/// 물고기/먹이/부스러기의 시뮬레이션. 프레임 단위로 상태를 갱신하므로 의도적으로 가변 참조 타입이다.
public final class Simulation {
    public private(set) var fish: [Fish] = []
    public private(set) var foods: [Food] = []
    public private(set) var crumbs: [Crumb] = []
    public private(set) var time: Double = 0
    public private(set) var tankRect: CGRect
    public private(set) var shape: TankShape

    /// 타이머 모드에서 물고기가 갉아먹는 시간 띠. nil이면 자유 유영.
    public var nibbleZone: NibbleZone?
    /// 이어 붙인 어항의 이음매 위치 (긴 축 좌표). 물고기가 지나가면 포털을 빠져나온 듯 빨라진다.
    public var seam: (position: CGFloat, vertical: Bool)?
    /// 물고기가 구경하러 가는 소품들
    public var attractions: [Attraction] = []
    /// 물고기 몸 크기 배율 (설정의 물고기 크기). 그림과 이동 범위가 같이 따른다.
    public var bodyScale: CGFloat = 1

    func bodySize(_ species: Species) -> CGFloat { species.size * bodyScale }

    /// 0...1. 타이머 종료 직후처럼 물고기가 들떠서 빠르게 돌아다닌다.
    public var excitement: Double = 0
    private var stepDelta: Double = 0
    private static let maxFoods = 24
    private static let foodLifetime = 15.0
    private static let eatDistance: CGFloat = 10

    public init(tankRect: CGRect, shape: TankShape) {
        self.tankRect = tankRect
        self.shape = shape
    }

    public func configure(tankRect: CGRect, shape: TankShape) {
        self.tankRect = tankRect
        self.shape = shape
        fish = fish.map { fish in
            var moved = fish
            moved.pos = shape.clamp(fish.pos, in: tankRect, margin: bodySize(fish.species) / 2)
            moved.target = moved.pos
            return moved
        }
    }

    /// 원하는 구성에 맞춰 기존 물고기는 유지하고 모자란 만큼만 새로 만든다.
    public func setFish(_ species: [Species]) {
        var pool = fish
        fish = species.map { wanted in
            if let index = pool.firstIndex(where: { $0.species == wanted }) {
                return pool.remove(at: index)
            }
            return spawn(wanted)
        }
    }

    public func dropFood(at point: CGPoint, kind: FoodKind = .pellets) {
        let origin = shape.clamp(point, in: tankRect, margin: 6)
        for _ in 0..<kind.dropCount where foods.count < Self.maxFoods {
            let jitter = CGPoint(x: .random(in: -10...10), y: .random(in: -5...5))
            let pos = shape.clamp(CGPoint(x: origin.x + jitter.x, y: origin.y + jitter.y), in: tankRect, margin: 6)
            foods.append(Food(kind: kind, pos: pos))
        }
    }

    public func step(_ dt: Double) {
        stepDelta = dt
        time += dt
        stepFoods(dt)
        stepCrumbs(dt)
        for index in fish.indices {
            fish[index] = crossingSeam(updated(fish[index], index: index, dt: dt))
        }
    }

    // MARK: - Private

    private func spawn(_ species: Species) -> Fish {
        let point = CGPoint(
            x: .random(in: tankRect.minX...tankRect.maxX),
            y: .random(in: tankRect.minY...tankRect.maxY)
        )
        return Fish(species: species, pos: shape.clamp(point, in: tankRect, margin: bodySize(species) / 2))
    }

    private func randomPoint(margin: CGFloat) -> CGPoint {
        let point = CGPoint(
            x: .random(in: tankRect.minX...tankRect.maxX),
            y: .random(in: tankRect.minY...tankRect.maxY)
        )
        return shape.clamp(point, in: tankRect, margin: margin)
    }

    private func stepFoods(_ dt: Double) {
        let floor = tankRect.maxY - 18
        foods = foods.compactMap { food in
            guard food.age < Self.foodLifetime else { return nil }
            var next = food
            next.age += dt
            if next.pos.y < floor { next.pos.y += food.kind.sinkSpeed * CGFloat(dt) }
            return next
        }
    }

    private func stepCrumbs(_ dt: Double) {
        let step = CGFloat(dt)
        crumbs = crumbs.compactMap { crumb in
            guard crumb.life > 0 else { return nil }
            var next = crumb
            next.life -= dt
            next.pos.x += crumb.vel.dx * step
            next.pos.y += crumb.vel.dy * step
            return next
        }
    }

    private func nearestFoodIndex(to point: CGPoint) -> Int? {
        foods.indices.min { distance(foods[$0].pos, point) < distance(foods[$1].pos, point) }
    }

    private func crossingSeam(_ input: Fish) -> Fish {
        guard let seam else { return input }
        var fish = input
        let side = (seam.vertical ? fish.pos.y : fish.pos.x) < seam.position ? -1 : 1
        if fish.seamSide != 0, side != fish.seamSide {
            fish.dash = 1
            fish.vel.dx *= 2.4
            fish.vel.dy *= 2.4
        }
        fish.seamSide = side
        return fish
    }

    private func updated(_ input: Fish, index: Int, dt: Double) -> Fish {
        var fish = input
        let species = fish.species
        var desired = fish.target
        var cruise = species.speed * 0.6
        fish.isNibbling = false
        if excitement > 0 { fish.retargetIn = min(fish.retargetIn, 0.5) }
        var nibbleSpot: NibbleZone.Spot?
        fish.eatPulse = max(0, fish.eatPulse - dt)
        fish.dash = max(0, fish.dash - dt / 1.2)

        if let foodIndex = nearestFoodIndex(to: fish.pos) {
            desired = foods[foodIndex].pos
            cruise = species.speed * 1.3
            if distance(fish.pos, desired) < Self.eatDistance + foods[foodIndex].kind.radius {
                // 먹이 옆에 머물며 조금씩 갉는다. 여러 마리가 같은 먹이를 함께 먹을 수 있다.
                cruise = species.speed * 0.25
                foods[foodIndex].remaining -= dt / foods[foodIndex].kind.eatSeconds
                if fish.eatPulse <= 0, Double.random(in: 0...1) < dt * 2.5 { fish.eatPulse = 0.3 }
                if Double.random(in: 0...1) < dt * 5 {
                    crumbs.append(Crumb(
                        pos: foods[foodIndex].pos,
                        vel: CGVector(dx: .random(in: -8...8), dy: .random(in: 6...20)),
                        life: 0.7
                    ))
                }
                if foods[foodIndex].remaining <= 0 { foods.remove(at: foodIndex) }
            }
        } else if let zone = nibbleZone {
            let spot = zone.spot(index: index, size: bodySize(species), phase: fish.phase, time: time)
            desired = spot.center
            cruise = species.speed * 1.4
            fish.isNibbling = distance(fish.pos, spot.center) < 8
            fish.visiting = nil
            nibbleSpot = spot
        } else {
            wander(&fish)
            desired = fish.target
            if fish.visiting != nil, distance(fish.pos, fish.target) < 10 {
                desired.x += CGFloat(sin(time * 1.3 + fish.phase)) * 6
                desired.y += CGFloat(cos(time * 1.1 + fish.phase)) * 3
            }
        }
        fish.isInside = fish.visiting.map { $0 == .cave || $0 == .castle } == true && distance(fish.pos, fish.target) < 14

        steer(&fish, toward: desired, cruise: cruise * CGFloat(1 + excitement * 1.6 + fish.dash * 1.8), dt: dt)

        let tiltGoal = fish.isNibbling ? (nibbleSpot?.tilt ?? 0) : 0
        fish.nibbleTilt += (tiltGoal - fish.nibbleTilt) * min(1, 6 * dt)
        if fish.isNibbling, let spot = nibbleSpot {
            fish.facingLeft = spot.facesLeft
            fish.pos.y += CGFloat(sin(time * 14 + fish.phase)) * 0.25
            if Double.random(in: 0...1) < dt * 6 {
                crumbs.append(Crumb(
                    pos: spot.bite,
                    vel: CGVector(dx: .random(in: -10...10), dy: .random(in: 10...30)),
                    life: 1
                ))
            }
        } else if abs(fish.vel.dx) > 4 {
            fish.facingLeft = fish.vel.dx < 0
        }
        return fish
    }

    /// 자유 유영: 가끔은 소품을 구경하러 가서 한동안 머문다.
    private func wander(_ fish: inout Fish) {
        fish.retargetIn -= stepDelta
        let arrived = distance(fish.pos, fish.target) < 8
        let lingering = fish.visiting != nil && arrived
        guard fish.retargetIn <= 0 || (arrived && !lingering) else { return }
        let margin = bodySize(fish.species) / 2
        if let place = pickAttraction(for: fish.species) {
            let jitter = place.isEnterable ? 4.0 : 12.0
            let spot = CGPoint(
                x: place.pos.x + .random(in: -jitter...jitter),
                y: place.pos.y + .random(in: -6...6)
            )
            fish.target = shape.clamp(spot, in: tankRect, margin: margin)
            fish.visiting = place.decor
            fish.retargetIn = .random(in: 5...9)
        } else {
            fish.target = randomPoint(margin: margin)
            fish.visiting = nil
            fish.retargetIn = .random(in: 2...5)
        }
    }

    private func pickAttraction(for species: Species) -> Attraction? {
        guard !attractions.isEmpty, Double.random(in: 0...1) < 0.45 else { return nil }
        let weights = attractions.map { place -> Double in
            species == .clownfish && place.decor == .anemone ? 4 : 1
        }
        var roll = Double.random(in: 0..<weights.reduce(0, +))
        for (index, weight) in weights.enumerated() {
            roll -= weight
            if roll < 0 { return attractions[index] }
        }
        return attractions.last
    }

    private func steer(_ fish: inout Fish, toward desired: CGPoint, cruise: CGFloat, dt: Double) {
        let dx = desired.x - fish.pos.x, dy = desired.y - fish.pos.y
        let dist = max(hypot(dx, dy), 0.001)
        let speed = min(cruise, dist * 3)
        let blend = CGFloat(min(1, 4 * dt))
        fish.vel.dx += (dx / dist * speed - fish.vel.dx) * blend
        fish.vel.dy += (dy / dist * speed - fish.vel.dy) * blend
        fish.pos.x += fish.vel.dx * CGFloat(dt)
        fish.pos.y += fish.vel.dy * CGFloat(dt)
        fish.pos = shape.clamp(fish.pos, in: tankRect, margin: bodySize(fish.species) / 2)
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }
}
