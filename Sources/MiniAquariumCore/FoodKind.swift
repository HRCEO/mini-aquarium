import CoreGraphics
import Foundation

/// 먹이 종류. 알갱이 수, 가라앉는 속도, 크기가 다르다.
public enum FoodKind: String, Codable, CaseIterable {
    case flakes, pellets, shrimp, algae

    public var title: String {
        switch self {
        case .flakes: return "플레이크"
        case .pellets: return "알갱이"
        case .shrimp: return "건조 새우"
        case .algae: return "해초 웨이퍼"
        }
    }

    /// 한 번 줄 때 떨어지는 개수
    public var dropCount: Int {
        switch self {
        case .flakes: return 6
        case .pellets: return 3
        case .shrimp: return 2
        case .algae: return 1
        }
    }

    /// 가라앉는 속도 (pt/s)
    public var sinkSpeed: CGFloat {
        switch self {
        case .flakes: return 12
        case .pellets: return 26
        case .shrimp: return 34
        case .algae: return 40
        }
    }

    /// 물고기 한 마리가 다 먹는 데 걸리는 시간(초). 클수록 오래 먹고, 여러 마리가 함께 먹으면 그만큼 빨리 줄어든다.
    public var eatSeconds: Double {
        switch self {
        case .flakes: return 0.7
        case .pellets: return 1.5
        case .shrimp: return 3.5
        case .algae: return 6
        }
    }

    /// 그려지는 반지름 (pt). 먹는 판정 거리에도 더해진다.
    public var radius: CGFloat {
        switch self {
        case .flakes: return 2.4
        case .pellets: return 3
        case .shrimp: return 5
        case .algae: return 7
        }
    }
}
