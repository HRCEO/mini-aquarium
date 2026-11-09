import CoreGraphics
import Foundation

/// 물고기 종류. 그림은 앱 쪽(FishArt)에서 벡터로 직접 그린다.
public enum Species: String, Codable, CaseIterable {
    case goldfish, tetra, clownfish, tang, angelfish, betta, puffer, seahorse, jellyfish
    case guppy, discus, koi, butterflyfish, moorishIdol

    public var title: String {
        switch self {
        case .goldfish: return "금붕어"
        case .tetra: return "네온테트라"
        case .clownfish: return "흰동가리"
        case .tang: return "블루탱"
        case .angelfish: return "엔젤피시"
        case .betta: return "베타"
        case .puffer: return "복어"
        case .seahorse: return "해마"
        case .jellyfish: return "해파리"
        case .guppy: return "구피"
        case .discus: return "디스커스"
        case .koi: return "코이"
        case .butterflyfish: return "나비고기"
        case .moorishIdol: return "무어리쉬 아이돌"
        }
    }

    /// 순항 속도 (pt/s)
    public var speed: CGFloat {
        switch self {
        case .goldfish: return 38
        case .tetra: return 62
        case .clownfish: return 48
        case .tang: return 58
        case .angelfish: return 36
        case .betta: return 34
        case .puffer: return 28
        case .seahorse: return 16
        case .jellyfish: return 14
        case .guppy: return 44
        case .discus: return 30
        case .koi: return 34
        case .butterflyfish: return 42
        case .moorishIdol: return 40
        }
    }

    /// 몸 길이 (pt). 그림의 기준 크기이기도 하다.
    public var size: CGFloat {
        switch self {
        case .goldfish: return 34
        case .tetra: return 26
        case .clownfish: return 30
        case .tang: return 34
        case .angelfish: return 36
        case .betta: return 36
        case .puffer: return 30
        case .seahorse: return 34
        case .jellyfish: return 34
        case .guppy: return 26
        case .discus: return 32
        case .koi: return 42
        case .butterflyfish: return 32
        case .moorishIdol: return 36
        }
    }

    /// 몸을 세우고 헤엄치는 종(기울이기 없음).
    public var isUpright: Bool { self == .seahorse || self == .jellyfish }
}
