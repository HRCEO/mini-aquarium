import Foundation

/// 사용자 설정. 값 타입이며 변경 메서드는 항상 새 복사본을 반환한다.
public struct AquariumSettings: Codable, Equatable {
    public static let maxFish = 50
    public static let timerMinutesRange = 1...600

    public private(set) var fish: [Species]
    public private(set) var shape: TankShape
    public private(set) var size: TankSize
    public private(set) var layout: TankLayout
    public private(set) var objectSize: ObjectSize
    public private(set) var decors: [Decor]
    public private(set) var food: FoodKind
    public private(set) var displayMode: DisplayMode
    public private(set) var clock: ClockStyle
    public private(set) var timerMinutes: Int
    public private(set) var targetMinuteOfDay: Int
    public private(set) var dockFit: Bool
    public private(set) var patrol: Bool
    public private(set) var dockEdge: DockEdge
    public private(set) var showTankClock: Bool
    public private(set) var showRemaining: Bool
    public private(set) var dockGap: Int
    public private(set) var showTimerFood: Bool
    public private(set) var menuBarClock: Bool
    public private(set) var statusFish: Species
    public private(set) var originX: Double?
    public private(set) var originY: Double?

    public init(
        fish: [Species] = [.goldfish, .clownfish, .tetra, .tetra],
        shape: TankShape = .rounded,
        size: TankSize = .medium,
        layout: TankLayout = .standard,
        objectSize: ObjectSize = .normal,
        decors: [Decor] = [.kelp, .branchCoral, .anemone, .cave],
        food: FoodKind = .pellets,
        displayMode: DisplayMode = .floating,
        clock: ClockStyle = ClockStyle(),
        timerMinutes: Int = 25,
        targetMinuteOfDay: Int = 18 * 60,
        dockFit: Bool = true,
        patrol: Bool = true,
        dockEdge: DockEdge = .before,
        showTankClock: Bool = true,
        showRemaining: Bool = true,
        dockGap: Int = 14,
        showTimerFood: Bool = true,
        menuBarClock: Bool = false,
        statusFish: Species = .goldfish,
        originX: Double? = nil,
        originY: Double? = nil
    ) {
        self.fish = fish
        self.shape = shape
        self.size = size
        self.layout = layout
        self.objectSize = objectSize
        self.decors = decors
        self.food = food
        self.displayMode = displayMode
        self.clock = clock
        self.timerMinutes = Self.timerMinutesRange.clamp(timerMinutes)
        self.targetMinuteOfDay = min(max(targetMinuteOfDay, 0), 1439)
        self.dockFit = dockFit
        self.patrol = patrol
        self.dockEdge = dockEdge
        self.showTankClock = showTankClock
        self.showRemaining = showRemaining
        self.dockGap = min(max(dockGap, 0), 80)
        self.showTimerFood = showTimerFood
        self.menuBarClock = menuBarClock
        self.statusFish = statusFish
        self.originX = originX
        self.originY = originY
    }

    // MARK: - Updates (새 값을 돌려준다)

    public func adding(_ species: Species) -> AquariumSettings {
        guard fish.count < Self.maxFish else { return self }
        return changed { $0.fish.append(species) }
    }

    /// 해당 종 한 마리를 뺀다 (마지막으로 추가된 것부터).
    public func removing(_ species: Species) -> AquariumSettings {
        guard let index = fish.lastIndex(of: species) else { return self }
        return changed { $0.fish.remove(at: index) }
    }

    public func removingLastFish() -> AquariumSettings {
        guard !fish.isEmpty else { return self }
        return changed { $0.fish.removeLast() }
    }

    /// 추천 구성: 여러 종류를 골고루, 너무 붐비지 않게 10마리.
    public static let recommendedFish: [Species] = [
        .goldfish, .clownfish, .tetra, .tetra, .tetra, .guppy, .guppy, .koi, .discus, .butterflyfish,
    ]

    public func resettingFish() -> AquariumSettings {
        changed { $0.fish = Self.recommendedFish }
    }

    public func count(of species: Species) -> Int { fish.filter { $0 == species }.count }

    public func with(shape: TankShape) -> AquariumSettings { changed { $0.shape = shape } }
    public func with(size: TankSize) -> AquariumSettings { changed { $0.size = size } }
    public func with(layout: TankLayout) -> AquariumSettings { changed { $0.layout = layout } }
    public func with(objectSize: ObjectSize) -> AquariumSettings { changed { $0.objectSize = objectSize } }
    public func with(food: FoodKind) -> AquariumSettings { changed { $0.food = food } }
    public func with(displayMode: DisplayMode) -> AquariumSettings { changed { $0.displayMode = displayMode } }
    public func with(clock: ClockStyle) -> AquariumSettings { changed { $0.clock = clock } }

    public func with(timerMinutes: Int) -> AquariumSettings {
        changed { $0.timerMinutes = Self.timerMinutesRange.clamp(timerMinutes) }
    }

    public func with(targetMinuteOfDay value: Int) -> AquariumSettings {
        changed { $0.targetMinuteOfDay = ((value % 1440) + 1440) % 1440 }
    }

    public func with(dockFit: Bool) -> AquariumSettings { changed { $0.dockFit = dockFit } }
    public func with(dockEdge: DockEdge) -> AquariumSettings { changed { $0.dockEdge = dockEdge } }
    public func with(patrol: Bool) -> AquariumSettings { changed { $0.patrol = patrol } }
    public func with(showRemaining: Bool) -> AquariumSettings { changed { $0.showRemaining = showRemaining } }
    public func with(statusFish: Species) -> AquariumSettings { changed { $0.statusFish = statusFish } }
    public func with(dockGap: Int) -> AquariumSettings { changed { $0.dockGap = min(max(dockGap, 0), 80) } }
    public func with(showTimerFood: Bool) -> AquariumSettings { changed { $0.showTimerFood = showTimerFood } }
    public func with(showTankClock: Bool) -> AquariumSettings { changed { $0.showTankClock = showTankClock } }
    public func with(menuBarClock: Bool) -> AquariumSettings { changed { $0.menuBarClock = menuBarClock } }

    public func with(origin: CGPoint) -> AquariumSettings {
        changed {
            $0.originX = Double(origin.x)
            $0.originY = Double(origin.y)
        }
    }

    public func toggling(_ decor: Decor) -> AquariumSettings {
        changed { next in
            if let index = next.decors.firstIndex(of: decor) {
                next.decors.remove(at: index)
            } else {
                next.decors.append(decor)
            }
        }
    }

    private func changed(_ change: (inout AquariumSettings) -> Void) -> AquariumSettings {
        var copy = self
        change(&copy)
        return copy
    }

    // MARK: - Codable (필드가 늘어도 예전 저장값을 읽을 수 있게 관대하게 디코딩)

    private enum CodingKeys: String, CodingKey {
        case fish, shape, size, layout, objectSize, decors, food, displayMode, clock, timerMinutes, targetMinuteOfDay, dockFit, patrol, dockEdge, showTankClock, showRemaining, dockGap, showTimerFood, menuBarClock, statusFish, originX, originY
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AquariumSettings()
        let fishNames = try container.decodeIfPresent([String].self, forKey: .fish)
        let decorNames = try container.decodeIfPresent([String].self, forKey: .decors)
        self.init(
            fish: fishNames.map { $0.compactMap(Species.init(rawValue:)) } ?? defaults.fish,
            shape: (try? container.decode(TankShape.self, forKey: .shape)) ?? defaults.shape,
            size: (try? container.decode(TankSize.self, forKey: .size)) ?? defaults.size,
            layout: (try? container.decode(TankLayout.self, forKey: .layout)) ?? defaults.layout,
            objectSize: (try? container.decode(ObjectSize.self, forKey: .objectSize)) ?? defaults.objectSize,
            decors: decorNames.map { $0.compactMap(Decor.init(rawValue:)) } ?? defaults.decors,
            food: (try? container.decode(FoodKind.self, forKey: .food)) ?? defaults.food,
            displayMode: (try? container.decode(DisplayMode.self, forKey: .displayMode)) ?? defaults.displayMode,
            clock: (try? container.decode(ClockStyle.self, forKey: .clock)) ?? defaults.clock,
            timerMinutes: (try? container.decode(Int.self, forKey: .timerMinutes)) ?? defaults.timerMinutes,
            targetMinuteOfDay: (try? container.decode(Int.self, forKey: .targetMinuteOfDay)) ?? defaults.targetMinuteOfDay,
            dockFit: (try? container.decode(Bool.self, forKey: .dockFit)) ?? defaults.dockFit,
            patrol: (try? container.decode(Bool.self, forKey: .patrol)) ?? defaults.patrol,
            dockEdge: (try? container.decode(DockEdge.self, forKey: .dockEdge)) ?? defaults.dockEdge,
            showTankClock: (try? container.decode(Bool.self, forKey: .showTankClock)) ?? defaults.showTankClock,
            showRemaining: (try? container.decode(Bool.self, forKey: .showRemaining)) ?? defaults.showRemaining,
            dockGap: (try? container.decode(Int.self, forKey: .dockGap)) ?? defaults.dockGap,
            showTimerFood: (try? container.decode(Bool.self, forKey: .showTimerFood)) ?? defaults.showTimerFood,
            menuBarClock: (try? container.decode(Bool.self, forKey: .menuBarClock)) ?? defaults.menuBarClock,
            statusFish: (try? container.decode(Species.self, forKey: .statusFish)) ?? defaults.statusFish,
            originX: try container.decodeIfPresent(Double.self, forKey: .originX),
            originY: try container.decodeIfPresent(Double.self, forKey: .originY)
        )
    }
}

private extension ClosedRange where Bound == Int {
    func clamp(_ value: Int) -> Int { Swift.min(Swift.max(value, lowerBound), upperBound) }
}

public enum SettingsStore {
    public static let key = "MiniAquarium.settings.v2"

    public static func load(from defaults: UserDefaults = .standard) -> AquariumSettings {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(AquariumSettings.self, from: data)
        else { return AquariumSettings() }
        return decoded
    }

    public static func save(_ settings: AquariumSettings, to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
