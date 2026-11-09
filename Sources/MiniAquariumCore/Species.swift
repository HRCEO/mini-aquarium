import CoreGraphics
import Foundation

/// 물고기 종류. 그림은 앱 쪽(FishArt)에서 벡터로 직접 그린다.
public enum Species: String, Codable, CaseIterable {
    case goldfish, tetra, clownfish, tang, angelfish, betta, puffer, seahorse, jellyfish
    case guppy, discus, koi, butterflyfish, moorishIdol

    public var title: String {
        switch self {
        case .goldfish: return tr("금붕어", "Goldfish")
        case .tetra: return tr("네온테트라", "Neon tetra")
        case .clownfish: return tr("흰동가리", "Clownfish")
        case .tang: return tr("블루탱", "Blue tang")
        case .angelfish: return tr("엔젤피시", "Angelfish")
        case .betta: return tr("베타", "Betta")
        case .puffer: return tr("복어", "Pufferfish")
        case .seahorse: return tr("해마", "Seahorse")
        case .jellyfish: return tr("해파리", "Jellyfish")
        case .guppy: return tr("구피", "Guppy")
        case .discus: return tr("디스커스", "Discus")
        case .koi: return tr("코이", "Koi")
        case .butterflyfish: return tr("나비고기", "Butterflyfish")
        case .moorishIdol: return tr("무어리쉬 아이돌", "Moorish idol")
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
