import CoreGraphics
import Testing
@testable import MiniAquariumCore

@Suite("TimerState")
struct TimerStateTests {
    @Test("남은 시간은 종료 시각 기준으로 계산된다")
    func remainingUsesEndDate() {
        let timer = FixedTimer(duration: 600)
        #expect(timer.remaining(after: 100) == 500)
        #expect(timer.remaining(after: 700) == 0)
    }

    @Test("비율은 1에서 0으로 줄고 범위를 벗어나지 않는다")
    func ratioIsClamped() {
        let timer = FixedTimer(duration: 100)
        #expect(timer.ratio(after: 0) == 1)
        #expect(timer.ratio(after: 25) == 0.75)
        #expect(timer.ratio(after: 500) == 0)
        #expect(timer.ratio(after: -50) == 1)
    }

    @Test("종료 판정은 종료 시각 이상이면 참")
    func finishedAtEnd() {
        let timer = FixedTimer(duration: 10)
        #expect(!timer.isFinished(after: 9.9))
        #expect(timer.isFinished(after: 10))
    }

    @Test("표시 형식", arguments: [
        (0.0, "00:00"), (0.2, "00:01"), (59.0, "00:59"),
        (61.0, "01:01"), (3599.0, "59:59"), (3600.0, "1:00:00"), (-5.0, "00:00"),
    ])
    func formatsSeconds(seconds: Double, expected: String) {
        #expect(TimerState.format(seconds) == expected)
    }
}

@Suite("TankShape")
struct TankShapeTests {
    private let size = CGSize(width: 300, height: 260)

    @Test("타원형은 사각 모서리 점을 타원 경계 안으로 투영한다")
    func ellipseClampsCorner() {
        let rect = TankShape.bowl.rect(in: size)
        let corner = CGPoint(x: rect.maxX, y: rect.minY)
        let clamped = TankShape.bowl.clamp(corner, in: rect, margin: 0)
        let a = rect.width / 2, b = rect.height / 2
        let nx = (clamped.x - rect.midX) / a, ny = (clamped.y - rect.midY) / b
        #expect(hypot(nx, ny) <= 1.0001)
    }

    @Test("사각형은 범위 밖 점을 경계로 되돌린다")
    func rectClamps() {
        let rect = TankShape.rounded.rect(in: size)
        let clamped = TankShape.rounded.clamp(CGPoint(x: -100, y: 999), in: rect, margin: 10)
        #expect(clamped.x == rect.minX + 10)
        #expect(clamped.y == rect.maxY - 10)
    }

    @Test("시간 띠는 비율만큼 줄고 왼쪽 끝이 고정된다")
    func stripShrinksFromRight() {
        let rect = TankShape.rounded.rect(in: size)
        let full = TankShape.rounded.stripRect(in: rect, ratio: 1)
        let half = TankShape.rounded.stripRect(in: rect, ratio: 0.5)
        #expect(half.minX == full.minX)
        #expect(abs(half.width - full.width / 2) < 0.001)
    }
}

@Suite("AquariumSettings")
struct SettingsTests {
    @Test("물고기는 최대 마릿수를 넘기지 않는다")
    func fishCapped() {
        let full = AquariumSettings(fish: Array(repeating: .goldfish, count: AquariumSettings.maxFish))
        #expect(full.adding(.angelfish).fish.count == AquariumSettings.maxFish)
    }

    @Test("변경은 원본을 건드리지 않는다")
    func immutability() {
        let original = AquariumSettings()
        _ = original.adding(.angelfish).with(shape: .bowl).toggling(.fanCoral)
        #expect(original == AquariumSettings())
    }

    @Test("소품은 토글된다")
    func toggleDecor() {
        let base = AquariumSettings(decors: [])
        let on = base.toggling(.kelp)
        #expect(on.decors == [.kelp])
        #expect(on.toggling(.kelp).decors.isEmpty)
    }

    @Test("저장 후 다시 불러오면 같다")
    func roundTrip() throws {
        let store = try #require(EphemeralDefaults())
        defer { store.cleanup() }
        let settings = AquariumSettings().adding(.puffer).with(shape: .tall).with(size: .large).with(food: .shrimp).with(displayMode: .menuBar).with(timerMinutes: 40).with(origin: CGPoint(x: 5, y: 7))
        SettingsStore.save(settings, to: store.defaults)
        #expect(SettingsStore.load(from: store.defaults) == settings)
    }
}

@Suite("Simulation")
struct SimulationTests {
    private func makeSimulation(shape: TankShape = .rounded) -> Simulation {
        Simulation(tankRect: shape.rect(in: CGSize(width: 300, height: 260)), shape: shape)
    }

    @Test("setFish는 기존 물고기를 유지하고 구성을 맞춘다")
    func setFishReconciles() {
        let sim = makeSimulation()
        sim.setFish([.goldfish, .tetra])
        let keptID = sim.fish[0].id
        sim.setFish([.goldfish, .tetra, .angelfish])
        #expect(sim.fish.count == 3)
        #expect(sim.fish.first(where: { $0.species == .goldfish })?.id == keptID)
        sim.setFish([.angelfish])
        #expect(sim.fish.map(\.species) == [.angelfish])
    }

    @Test("먹이는 물고기가 가까이 가면 먹힌다")
    func foodGetsEaten() {
        let sim = makeSimulation()
        sim.setFish([.goldfish])
        sim.dropFood(at: CGPoint(x: sim.tankRect.midX, y: sim.tankRect.midY))
        #expect(!sim.foods.isEmpty)
        for _ in 0..<(30 * 20) { sim.step(1.0 / 30) }
        #expect(sim.foods.isEmpty)
    }

    @Test("물고기는 항상 어항 안에 머문다(타원형 포함)", arguments: TankShape.allCases)
    func fishStayInside(shape: TankShape) {
        let sim = makeSimulation(shape: shape)
        sim.setFish(Array(repeating: .angelfish, count: 6))
        for _ in 0..<600 { sim.step(1.0 / 30) }
        for fish in sim.fish {
            let clamped = shape.clamp(fish.pos, in: sim.tankRect, margin: fish.species.size / 2)
            #expect(abs(clamped.x - fish.pos.x) < 0.01 && abs(clamped.y - fish.pos.y) < 0.01)
        }
    }

    @Test("시간 띠가 있으면 물고기가 띠 주변으로 모인다")
    func fishGatherAtNibblePoint() {
        let sim = makeSimulation()
        sim.setFish([.tetra, .goldfish])
        let zone = NibbleZone.make(shape: .rounded, layout: .standard, in: sim.tankRect)
        sim.nibbleZone = zone
        for _ in 0..<(30 * 10) { sim.step(1.0 / 30) }
        let area = zone.bar.insetBy(dx: -50, dy: -50)
        for fish in sim.fish {
            #expect(area.contains(fish.pos))
        }
    }
}

@Suite("FoodKind / TankSize")
struct VariantTests {
    @Test("먹이 종류마다 떨어지는 개수가 다르다", arguments: FoodKind.allCases)
    func dropCounts(kind: FoodKind) {
        let sim = Simulation(tankRect: TankShape.rounded.rect(in: CGSize(width: 300, height: 260)), shape: .rounded)
        sim.dropFood(at: CGPoint(x: 150, y: 100), kind: kind)
        #expect(sim.foods.count == kind.dropCount)
    }

    @Test("크기 배율이 창 크기에 반영된다")
    func windowScales() {
        let base = CGSize(width: 300, height: 260)
        #expect(TankSize.medium.windowSize(base: base) == base)
        #expect(TankSize.large.windowSize(base: base).width == 420)
    }

    @Test("그리는 순서는 뒤 레이어부터")
    func drawOrder() {
        let order = Decor.drawOrder(Decor.allCases).map(\.layer)
        #expect(order == order.sorted())
    }
}

@Suite("Settings 저장")
struct SettingsStoreTests {
    @Test("옛 저장값도 기본값으로 읽힌다")
    func lenientDecode() throws {
        let store = try #require(EphemeralDefaults())
        defer { store.cleanup() }
        store.writeRaw("{\"fish\":[\"goldfish\",\"ghost\"],\"shape\":\"bowl\"}")
        let loaded = SettingsStore.load(from: store.defaults)
        #expect(loaded.fish == [.goldfish])
        #expect(loaded.shape == .bowl)
        #expect(loaded.displayMode == .floating)
    }

    @Test("잘못된 위치 값이 있어도 나머지 설정은 살아남는다")
    func corruptOriginKeepsOtherSettings() throws {
        let store = try #require(EphemeralDefaults())
        defer { store.cleanup() }
        store.writeRaw("{\"shape\":\"bowl\",\"originX\":\"oops\"}")
        let loaded = SettingsStore.load(from: store.defaults)
        #expect(loaded.shape == .bowl)
        #expect(loaded.originX == nil)
    }
}

@Suite("Layout / Attractions")
struct LayoutTests {
    @Test("세로 레이아웃의 시간 띠는 세로로 놓인다")
    func slimBarIsVertical() {
        let rect = TankShape.rounded.rect(in: TankLayout.slim.logicalSize)
        let zone = NibbleZone.make(shape: .rounded, layout: .slim, in: rect)
        #expect(zone.isVertical)
        #expect(zone.bar.height > zone.bar.width)
    }

    @Test("먹히는 순서는 모든 칸을 한 번씩 포함하고 타이머마다 다르다")
    func patternCoversAllCells() {
        let a = BitePattern(), b = BitePattern()
        #expect(Set(a.order).count == a.cellCount)
        #expect(a.order != b.order)
        #expect(a.order != Array(0..<a.cellCount))
    }

    @Test("물고기가 갉은 만큼만 칸이 줄고 한 칸은 한 마리가 맡는다")
    func bitingReducesTotal() {
        var field = BiteField()
        var generator = SystemRandomNumberGenerator()
        let first = field.claim(forFish: 0, crew: 2, using: &generator)
        let second = field.claim(forFish: 1, crew: 2, using: &generator)
        #expect(first != nil && second != nil && first != second)
        field.bite(cell: first!, amount: 0.4)
        #expect(abs(field.total - 0.4) < 0.0001)
        field.bite(cell: first!, amount: 5)
        #expect(field.eaten[first!] == 1)
        // 다 먹힌 칸은 새 칸으로 바뀐다
        #expect(field.claim(forFish: 0, crew: 2, using: &generator) != first)
    }

    @Test("미리 먹힌 칸 수만큼 채운다")
    func presetFillsInOrder() {
        var field = BiteField()
        field.preset(cells: 10.5)
        #expect(abs(field.total - 10.5) < 0.0001)
    }

    @Test("타이머 중 먹이가 있으면 띠를 갉지 않는다")
    func foodPausesNibbling() {
        let sim = Simulation(tankRect: TankShape.rounded.rect(in: TankLayout.standard.logicalSize), shape: .rounded)
        sim.setFish([Species.tetra])
        sim.nibbleZone = NibbleZone.make(shape: .rounded, layout: .standard, in: sim.tankRect)
        sim.nibbleRate = 1
        sim.dropFood(at: CGPoint(x: sim.tankRect.midX, y: sim.tankRect.midY))
        let before = sim.bites.total
        sim.step(1.0 / 30)
        #expect(sim.bites.total == before)
    }

    @Test("소품이 있으면 물고기가 구경하러 간다")
    func fishVisitAttractions() {
        let sim = Simulation(tankRect: TankShape.rounded.rect(in: TankLayout.standard.logicalSize), shape: .rounded)
        sim.setFish([.clownfish])
        let spot = CGPoint(x: sim.tankRect.maxX - 30, y: sim.tankRect.maxY - 40)
        sim.attractions = [Attraction(decor: .anemone, pos: spot)]
        var visited = false
        for _ in 0..<(30 * 120) {
            sim.step(1.0 / 30)
            if hypot(sim.fish[0].pos.x - spot.x, sim.fish[0].pos.y - spot.y) < 20 { visited = true; break }
        }
        #expect(visited)
    }

    @Test("레이아웃을 저장하고 되살린다")
    func layoutRoundTrip() throws {
        let store = try #require(EphemeralDefaults())
        defer { store.cleanup() }
        SettingsStore.save(AquariumSettings().with(layout: .wide), to: store.defaults)
        #expect(SettingsStore.load(from: store.defaults).layout == .wide)
    }
}

@Suite("Dock / TargetTime")
struct DockTests {
    @Test("세로 Dock이면 아이콘 줄 위와 아래에 같은 두께의 빈 띠가 생긴다")
    func rightDock() throws {
        let screen = CGRect(x: 0, y: 0, width: 1800, height: 1169)
        let visible = CGRect(x: 0, y: 0, width: 1742, height: 1130)
        let region = try #require(DockFit.region(screen: screen, visible: visible, dockItems: 12, tile: 48))
        let before = try #require(region.before), after = try #require(region.after)
        #expect(region.side == .right)
        #expect(before.minX == 1742 && before.width == 58 && before.maxY == 1130)
        #expect(after.minY == 0 && after.maxY < before.minY)
        #expect(region.strips(for: .both).count == 2)
        #expect(region.strips(for: .before) == [before])
    }

    @Test("측정된 아이콘 줄 영역이 있으면 그것을 기준으로 띠를 자른다")
    func measuredPill() throws {
        let screen = CGRect(x: 0, y: 0, width: 1800, height: 1169)
        let visible = CGRect(x: 0, y: 0, width: 1742, height: 1130)
        let pill = CGRect(x: 1742, y: 200, width: 58, height: 700)
        let region = try #require(DockFit.region(screen: screen, visible: visible, dockItems: 12, tile: 48, measuredPill: pill))
        #expect(region.before?.minY == 914)
        #expect(region.after?.maxY == 186)
    }

    @Test("Dock이 숨겨져 있으면 nil")
    func hiddenDock() {
        let screen = CGRect(x: 0, y: 0, width: 1800, height: 1169)
        let visible = CGRect(x: 0, y: 0, width: 1800, height: 1130)
        #expect(DockFit.region(screen: screen, visible: visible, dockItems: 12, tile: 48) == nil)
    }

    @Test("아래쪽 Dock은 오른쪽 빈 가로 영역")
    func bottomDock() throws {
        let screen = CGRect(x: 0, y: 0, width: 1800, height: 1169)
        let visible = CGRect(x: 0, y: 70, width: 1800, height: 1060)
        let region = try #require(DockFit.region(screen: screen, visible: visible, dockItems: 10, tile: 48))
        #expect(region.side == .bottom)
        #expect((region.before ?? region.after)?.height == 70)
    }

    @Test("목표 시각이 지났으면 내일로 넘긴다")
    func targetTimeRollsOver() {
        #expect(abs(FixedTimer.waitSeconds(offsetMinutes: 90) - 90 * 60) < 1)
        #expect(abs(FixedTimer.waitSeconds(offsetMinutes: -30) - (24 * 60 - 30) * 60) < 1)
    }

    @Test("목표 시각 설정은 하루 범위로 감싸진다")
    func targetWraps() {
        #expect(AquariumSettings().with(targetMinuteOfDay: -60).targetMinuteOfDay == 1380)
        #expect(AquariumSettings().with(targetMinuteOfDay: 1500).targetMinuteOfDay == 60)
    }
}

@Suite("SystemLoad")
struct SystemLoadTests {
    @Test("값은 0...1로 보정된다")
    func clampsValues() {
        let load = SystemLoad(cpu: 3, memory: -1, battery: .nan, isCharging: false)
        #expect(load.cpu == 1)
        #expect(load.memory == 0)
        #expect(load.battery == 0)
    }

    @Test("CPU가 높을수록 빨리 헤엄친다")
    func speedFollowsCPU() {
        #expect(SystemLoad(cpu: 0, memory: 0, battery: nil, isCharging: false).swimSpeed == 0.7)
        #expect(SystemLoad(cpu: 1, memory: 0, battery: nil, isCharging: false).swimSpeed == 2.0)
    }

    @Test("배터리가 줄면 물이 낮아지지만 충전 중이거나 배터리가 없으면 가득 찬다")
    func waterLevelFollowsBattery() {
        #expect(SystemLoad(cpu: 0, memory: 0, battery: 0, isCharging: false).waterLevel == 0.55)
        #expect(SystemLoad(cpu: 0, memory: 0, battery: 1, isCharging: false).waterLevel == 1)
        #expect(SystemLoad(cpu: 0, memory: 0, battery: 0.1, isCharging: true).waterLevel == 1)
        #expect(SystemLoad(cpu: 0, memory: 0, battery: nil, isCharging: false).waterLevel == 1)
    }

    @Test("메모리 사용이 70%를 넘어야 물이 흐려진다")
    func turbidityStartsAtSeventyPercent() {
        #expect(SystemLoad(cpu: 0, memory: 0.7, battery: nil, isCharging: false).turbidity == 0)
        #expect(SystemLoad(cpu: 0, memory: 1, battery: nil, isCharging: false).turbidity == 0.5)
    }
}

@Suite("Settings: 시스템 연동")
struct NewSettingsTests {
    @Test("옛 저장값에 키가 없어도 기본값으로 채워진다")
    func decodesOldPayload() throws {
        let store = try #require(EphemeralDefaults())
        defer { store.cleanup() }
        store.writeRaw(#"{"timerMinutes": 30}"#)
        let loaded = SettingsStore.load(from: store.defaults)
        #expect(loaded.systemLink == false)
        #expect(loaded.timerMinutes == 30)
    }

    @Test("저장하고 읽으면 값이 유지된다")
    func roundTrip() throws {
        let store = try #require(EphemeralDefaults())
        defer { store.cleanup() }
        let settings = AquariumSettings().with(timerMinutes: 50).with(systemLink: true)
        SettingsStore.save(settings, to: store.defaults)
        #expect(SettingsStore.load(from: store.defaults) == settings)
    }
}

@Suite("Simulation: 낮아진 수면")
struct WaterSurfaceTests {
    @Test("물이 낮으면 물고기는 수면 아래에만 머문다")
    func fishStayBelowSurface() {
        let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
        let sim = Simulation(tankRect: rect, shape: .rounded)
        sim.setFish([.goldfish, .tetra, .guppy])
        sim.waterLevel = 0.5
        for _ in 0..<600 { sim.step(1.0 / 30) }
        let surface = rect.minY + rect.height * 0.5
        #expect(sim.fish.allSatisfy { $0.pos.y >= surface })
    }

    @Test("물 높이와 속도 배율은 허용 범위로 보정된다")
    func clampsScales() {
        let sim = Simulation(tankRect: CGRect(x: 0, y: 0, width: 100, height: 100), shape: .rounded)
        sim.waterLevel = 0
        sim.speedScale = 99
        #expect(sim.waterLevel == 0.3)
        #expect(sim.speedScale == 3)
    }
}

@Suite("Critter: 바닥 생물")
struct CritterTests {
    private let perches = [Perch(slot: 0.5, halfWidth: 0.1, height: 20)]

    @Test("오래 걸어도 바닥 범위를 벗어나지 않는다")
    func staysInsideFloor() {
        var critter = Critter(kind: .crab, slot: 0.5)
        for _ in 0..<20_000 {
            critter.step(1.0 / 30, perches: perches)
            #expect(Critter.slotRange.contains(critter.slot))
        }
    }

    @Test("시작 위치는 범위 안으로 잘린다")
    func clampsInitialSlot() {
        #expect(Critter(kind: .crab, slot: -3).slot == Critter.slotRange.lowerBound)
        #expect(Critter(kind: .crab, slot: 9).slot == Critter.slotRange.upperBound)
    }

    @Test("발판 윗면에서는 높이만큼 올라서고, 밖에서는 0이다")
    func perchLift() {
        let perch = perches[0]
        #expect(perch.lift(at: 0.5) == 20)
        #expect(perch.lift(at: 0.9) == 0)
        let edge = perch.lift(at: 0.5 + perch.halfWidth * 0.8)
        #expect(edge > 0 && edge < 20)
    }

    @Test("게는 발판 위에 올라갔다 내려온다")
    func climbsPerch() {
        var critter = Critter(kind: .crab, slot: 0.5)
        var peak = 0.0
        for _ in 0..<60_000 {
            critter.step(1.0 / 30, perches: perches)
            peak = max(peak, critter.altitude)
            #expect(critter.altitude >= 0 && critter.altitude <= 20.001)
        }
        #expect(peak > 10)
    }

    @Test("발판은 올라설 수 있는 소품에서만 만들어진다")
    func perchesFromDecors() {
        let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
        let made = Perch.make(decors: [.kelp, .chest, .shells, .cave], scale: 1, rect: rect, shape: .rounded)
        #expect(made.count == 2)
        #expect(made.allSatisfy { $0.height > 0 && $0.halfWidth > 0 })
    }

    @Test("setCritters는 기존 개체를 재사용하고 모자란 만큼만 추가한다")
    func setCrittersReuses() {
        let sim = Simulation(tankRect: CGRect(x: 0, y: 0, width: 200, height: 100), shape: .rounded)
        sim.setCritters([.crab])
        let ids = sim.critters.map(\.id)
        sim.setCritters([.crab, .crab])
        #expect(sim.critters.count == 2)
        #expect(Set(ids).isSubset(of: Set(sim.critters.map(\.id))))
        sim.setCritters([])
        #expect(sim.critters.isEmpty)
    }

    @Test("설정에서 추가·제거하고 최대 마릿수를 지킨다")
    func settingsAddRemove() {
        var settings = AquariumSettings()
        for _ in 0..<(AquariumSettings.maxCritters + 3) { settings = settings.addingCritter(.crab) }
        #expect(settings.critters.count == AquariumSettings.maxCritters)
        #expect(settings.removingCritter(.crab).count(ofCritter: .crab) == AquariumSettings.maxCritters - 1)
    }

    @Test("옛 저장값에는 기본 생물이 채워지고, 없는 종류는 무시된다")
    func persistence() throws {
        let store = try #require(EphemeralDefaults())
        defer { store.cleanup() }
        store.writeRaw(#"{"timerMinutes": 30}"#)
        #expect(SettingsStore.load(from: store.defaults).critters == [.crab])
        store.writeRaw(#"{"critters": ["crab", "shrimp"]}"#)
        #expect(SettingsStore.load(from: store.defaults).critters == [.crab])
        let settings = AquariumSettings().addingCritter(.crab)
        SettingsStore.save(settings, to: store.defaults)
        #expect(SettingsStore.load(from: store.defaults) == settings)
    }

    @Test("바닥 좌표: 사각형은 그대로, 타원은 가장자리가 좁고 높다")
    func floorGeometry() {
        let rect = CGRect(x: 0, y: 0, width: 200, height: 100)
        #expect(TankShape.rounded.floorX(0.5, in: rect) == rect.minX + rect.width * 0.5)
        let bowl = TankShape.bowl
        let edge = bowl.floorY(atX: bowl.floorX(0.06, in: rect), in: rect, lift: 6)
        let mid = bowl.floorY(atX: bowl.floorX(0.5, in: rect), in: rect, lift: 6)
        #expect(edge < mid)
    }
}
