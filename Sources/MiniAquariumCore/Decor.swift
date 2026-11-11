import CoreGraphics
import Foundation

/// 어항 인테리어 소품. 바닥에 배치되고 `layer` 순서(뒤→앞)로 그려진다.
public enum Decor: String, Codable, CaseIterable {
    case cave, castle, kelp, branchCoral, fanCoral, anemone
    case rockPile, chest, driftwood, starfish, shells, bubbler

    public var title: String {
        switch self {
        case .cave: return tr("동굴", "Cave")
        case .castle: return tr("성", "Castle")
        case .kelp: return tr("켈프", "Kelp")
        case .branchCoral: return tr("가지 산호", "Branch coral")
        case .fanCoral: return tr("부채 산호", "Fan coral")
        case .anemone: return tr("말미잘", "Anemone")
        case .rockPile: return tr("바위 더미", "Rock pile")
        case .chest: return tr("보물상자", "Treasure chest")
        case .driftwood: return tr("유목", "Driftwood")
        case .starfish: return tr("불가사리", "Starfish")
        case .shells: return tr("조개", "Shells")
        case .bubbler: return tr("에어스톤", "Air stone")
        }
    }

    /// 그림의 기준 높이 (pt)
    public var height: CGFloat {
        switch self {
        case .cave: return 66
        case .castle: return 62
        case .kelp: return 78
        case .branchCoral: return 54
        case .fanCoral: return 56
        case .anemone: return 34
        case .rockPile: return 38
        case .chest: return 30
        case .driftwood: return 34
        case .starfish: return 16
        case .shells: return 14
        case .bubbler: return 16
        }
    }

    /// 그릴 때 곱하는 배율 (소품이 눈에 잘 띄도록 키운다)
    public static let displayScale: CGFloat = 1.35

    /// 0 = 뒤, 1 = 중간, 2 = 앞
    public var layer: Int {
        switch self {
        case .cave, .castle, .kelp: return 0
        case .branchCoral, .fanCoral, .driftwood, .rockPile: return 1
        case .anemone, .chest, .starfish, .shells, .bubbler: return 2
        }
    }

    /// 바닥 가로 위치 (0...1)
    public var slot: CGFloat {
        switch self {
        case .kelp: return 0.08
        case .castle: return 0.22
        case .branchCoral: return 0.35
        case .shells: return 0.41
        case .anemone: return 0.47
        case .driftwood: return 0.52
        case .bubbler: return 0.57
        case .starfish: return 0.62
        case .fanCoral: return 0.68
        case .chest: return 0.76
        case .cave: return 0.84
        case .rockPile: return 0.93
        }
    }

    /// 어항 모양(타원이면 가장자리가 좁아짐)에 맞춘 x 좌표.
    public func x(in rect: CGRect, shape: TankShape) -> CGFloat {
        shape.floorX(slot, in: rect)
    }

    /// 게가 올라설 수 있는 윗면 (그림 기준 pt): 중심 어긋남, 반폭, 높이. 올라설 수 없는 소품은 nil.
    public var perchProfile: (offset: CGFloat, halfWidth: CGFloat, height: CGFloat)? {
        let h = height
        switch self {
        case .cave: return (0.1 * h, 0.4 * h, 0.85 * h)
        case .castle: return (0, 13, 0.62 * h)
        case .rockPile: return (0, 11, 0.75 * h)
        case .chest: return (0, 12, 0.8 * h)
        case .driftwood: return (14, 8, 0.55 * h)
        default: return nil
        }
    }

    /// 뒤→앞 순서로 정렬한다 (같은 layer는 slot 순).
    public static func drawOrder(_ decors: [Decor]) -> [Decor] {
        decors.sorted { ($0.layer, $0.slot) < ($1.layer, $1.slot) }
    }
}
