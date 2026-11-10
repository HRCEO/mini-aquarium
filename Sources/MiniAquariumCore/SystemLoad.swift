import Foundation

/// 어항에 반영할 시스템 상태. 모든 값은 0...1로 보정된다.
public struct SystemLoad: Equatable {
    public let cpu: Double
    public let memory: Double
    /// 배터리 잔량. 배터리가 없는 Mac이면 nil.
    public let battery: Double?
    public let isCharging: Bool

    public static let idle = SystemLoad(cpu: 0, memory: 0, battery: nil, isCharging: false)

    public init(cpu: Double, memory: Double, battery: Double?, isCharging: Bool) {
        self.cpu = Self.unit(cpu)
        self.memory = Self.unit(memory)
        self.battery = battery.map(Self.unit)
        self.isCharging = isCharging
    }

    /// 물고기 헤엄 속도 배율. CPU가 한가하면 느긋하고(0.7), 바쁘면 부산하다(2.0).
    public var swimSpeed: Double { 0.7 + cpu * 1.3 }

    /// 물 높이 (0.55...1). 배터리가 줄면 물이 낮아진다. 충전 중이거나 배터리가 없으면 가득 찬다.
    public var waterLevel: Double {
        guard let battery, !isCharging else { return 1 }
        return 0.55 + battery * 0.45
    }

    /// 물 탁한 정도 (0...0.5). 메모리 사용이 70%를 넘으면서부터 흐려진다.
    public var turbidity: Double {
        min(1, max(0, (memory - 0.7) / 0.3)) * 0.5
    }

    private static func unit(_ value: Double) -> Double {
        value.isNaN ? 0 : min(max(value, 0), 1)
    }
}
