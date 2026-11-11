import CoreGraphics
import Foundation

/// 물고기마다 다른 헤엄 성격. 같은 종이어도 움직임이 제각각이 되게 한다.
public struct SwimStyle {
    /// 유영 속도 배율
    public let speed = Double.random(in: 0.75...1.3)
    /// 목적지에 머무는 시간 배율 (작으면 부산하고, 크면 느긋하다)
    public let dwell = Double.random(in: 0.4...1.9)
    /// 좋아하는 깊이 (0 = 수면, 1 = 바닥)
    public let depth = Double.random(in: 0.1...0.85)
    /// 선호 깊이 주변으로 퍼지는 정도
    public let depthSpread = Double.random(in: 0.12...0.45)
    /// 가로로 돌아다니는 범위 비율 (1에 가까우면 어항 전체를 누빈다)
    public let roam = Double.random(in: 0.25...1)
    /// 소품을 구경하러 가는 성향 배율
    public let curiosity = Double.random(in: 0.4...2)
}

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
    public let style = SwimStyle()
    /// 주로 머무는 가로 위치 (0...1). 가끔 다른 곳으로 옮겨 간다.
    var homeX = Double.random(in: 0...1)
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
    public private(set) var critters: [Critter] = []
    public private(set) var time: Double = 0
    public private(set) var tankRect: CGRect
    public private(set) var shape: TankShape

    /// 타이머 모드에서 물고기가 갉아먹는 시간 띠. nil이면 자유 유영.
    public var nibbleZone: NibbleZone?
    /// 띠의 칸별 먹힌 정도. 물고기가 갉는 만큼만 줄어든다.
    public private(set) var bites = BiteField()
    /// 지금까지 먹혔어야 하는 칸 수 (시간 비율에 따른 목표). 뒤처지면 물고기가 더 빨리 갉아 따라잡는다.
    public var nibbleTarget: Double = 0
    /// 목표가 늘어나는 속도 (칸/초)
    public var nibbleRate: Double = 0
    /// 이어 붙인 어항의 이음매 위치 (긴 축 좌표). 물고기가 지나가면 포털을 빠져나온 듯 빨라진다.
    public var seam: (position: CGFloat, vertical: Bool)?
    /// 물고기가 구경하러 가는 소품들
    public var attractions: [Attraction] = []
    /// 게가 올라설 수 있는 소품 윗면
    public var perches: [Perch] = []
    /// 물고기 몸 크기 배율 (설정의 물고기 크기). 그림과 이동 범위가 같이 따른다.
    public var bodyScale: CGFloat = 1

    func bodySize(_ species: Species) -> CGFloat { species.size * bodyScale }

    /// 0...1. 타이머 종료 직후처럼 물고기가 들떠서 빠르게 돌아다닌다.
    public var excitement: Double = 0
    /// 물이 차 있는 비율 (0.3...1). 낮으면 물고기는 수면 아래에만 머문다.
    public var waterLevel: Double = 1 { didSet { waterLevel = min(max(waterLevel, 0.3), 1) } }
    /// 헤엄 속도 배율 (시스템 연동 등). 1이 기본이고 0.3...3 범위로 보정된다.
    public var speedScale: Double = 1 { didSet { speedScale = min(max(speedScale, 0.3), 3) } }
    private var stepDelta: Double = 0
    private var generator = SystemRandomNumberGenerator()
    private static let maxFoods = 24
    private static let foodLifetime = 15.0
    private static let eatDistance: CGFloat = 10
    private static let arriveDistance: CGFloat = 10

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

    /// 원하는 구성에 맞춰 기존 바닥 생물은 유지하고 모자란 만큼만 새로 만든다.
    public func setCritters(_ kinds: [CritterKind]) {
        var pool = critters
        critters = kinds.map { wanted in
            if let index = pool.firstIndex(where: { $0.kind == wanted }) {
                return pool.remove(at: index)
            }
            return Critter(kind: wanted)
        }
    }

    /// 새 타이머를 시작한다. 띠가 사라질 순서를 새로 뽑는다.
    public func resetBites(cellsAlreadyEaten: Double = 0) {
        bites = BiteField()
        bites.preset(cells: cellsAlreadyEaten)
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
        for index in critters.indices { critters[index].step(dt, perches: perches) }
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

    /// 갉고 있는 물고기 한 마리가 한 프레임에 먹는 칸 수. 전체 속도가 시간 흐름과 맞고, 뒤처졌으면 더 빨리 먹는다.
    private func nibbleAmount(_ dt: Double) -> Double {
        let crew = Double(max(fish.filter(\.isNibbling).count, 1))
        let gain = min(max(1 + (nibbleTarget - bites.total) * 0.5, 0.15), 8)
        return nibbleRate * gain / crew * dt
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
        var cruise = species.speed * 0.6 * CGFloat(fish.style.speed)
        fish.isNibbling = false
        if excitement > 0 { fish.retargetIn = min(fish.retargetIn, 0.5) }
        var nibbleSpot: NibbleZone.Spot?
        var biteCell = 0, biteAmount = 0.0
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
        } else if let zone = nibbleZone, let cell = bites.claim(forFish: index, crew: self.fish.count, using: &generator) {
            let spot = zone.spot(cell: cell, index: index, size: bodySize(species))
            desired = spot.center
            cruise = species.speed * 1.4
            fish.isNibbling = distance(fish.pos, spot.center) < 8
            if fish.isNibbling { biteAmount = nibbleAmount(dt) ; biteCell = cell }
            fish.visiting = nil
            nibbleSpot = spot
        } else {
            wander(&fish)
            desired = fish.target
            if distance(fish.pos, fish.target) < 10 {
                desired.x += CGFloat(sin(time * 1.3 + fish.phase)) * 6
                desired.y += CGFloat(cos(time * 1.1 + fish.phase)) * 3
            }
        }
        if biteAmount > 0 { bites.bite(cell: biteCell, amount: biteAmount, side: index % 2) }
        fish.isInside = fish.visiting.map { $0 == .cave || $0 == .castle } == true && distance(fish.pos, fish.target) < 14

        steer(&fish, toward: desired, cruise: cruise * CGFloat(1 + excitement * 1.6 + fish.dash * 1.8) * CGFloat(speedScale), dt: dt)

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
        // 머무는 시간은 목적지에 도착한 뒤부터 센다. 긴 어항에서 도착도 못 하고 목적지가 바뀌면 제자리만 맴돈다.
        if distance(fish.pos, fish.target) < Self.arriveDistance { fish.retargetIn -= stepDelta }
        guard fish.retargetIn <= 0 else { return }
        let margin = bodySize(fish.species) / 2
        if let place = pickAttraction(for: fish.species, curiosity: fish.style.curiosity) {
            let jitter = place.isEnterable ? 4.0 : 12.0
            let spot = CGPoint(
                x: place.pos.x + .random(in: -jitter...jitter),
                y: place.pos.y + .random(in: -6...6)
            )
            fish.target = shape.clamp(spot, in: tankRect, margin: margin)
            fish.visiting = place.decor
            fish.retargetIn = Double.random(in: 5...9) * fish.style.dwell
        } else {
            fish.target = stylePoint(&fish, margin: margin)
            fish.visiting = nil
            fish.retargetIn = Double.random(in: 3...6) * fish.style.dwell
        }
    }

    /// 물고기의 성격(선호 깊이, 활동 범위)에 맞춘 다음 목적지.
    private func stylePoint(_ fish: inout Fish, margin: CGFloat) -> CGPoint {
        let style = fish.style
        // 가끔 활동 중심을 옮긴다. 오래 지켜보면 어항 구석구석에 가게 된다.
        if Double.random(in: 0...1) < 0.2 { fish.homeX = .random(in: 0...1) }
        let halfRange = style.roam / 2
        let fractionX = min(max(fish.homeX + .random(in: -halfRange...halfRange), 0), 1)
        // 두 난수의 평균으로 선호 깊이 주변에 모이는 분포를 만든다.
        let bell = (Double.random(in: -1...1) + Double.random(in: -1...1)) / 2
        let fractionY = min(max(style.depth + bell * style.depthSpread * 2, 0), 1)
        let point = CGPoint(
            x: tankRect.minX + tankRect.width * CGFloat(fractionX),
            y: tankRect.minY + tankRect.height * CGFloat(fractionY)
        )
        return shape.clamp(point, in: tankRect, margin: margin)
    }

    private func pickAttraction(for species: Species, curiosity: Double) -> Attraction? {
        guard !attractions.isEmpty, Double.random(in: 0...1) < min(0.3 * curiosity, 0.7) else { return nil }
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
        let surface = tankRect.minY + tankRect.height * CGFloat(1 - waterLevel)
        fish.pos.y = max(fish.pos.y, surface + bodySize(fish.species) / 2)
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }
}
