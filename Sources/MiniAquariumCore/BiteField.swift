import Foundation

/// 시간 띠의 칸별로 얼마나 먹혔는지(0...1)와, 어느 물고기가 어느 칸을 맡았는지.
/// 칸은 물고기가 실제로 그 자리에서 갉을 때만 줄어든다.
public struct BiteField {
    public private(set) var pattern: BitePattern
    public private(set) var eaten: [Double]
    /// 먹힌 칸 수의 합 (0...cellCount)
    public private(set) var total: Double = 0
    /// 칸을 갉는 물고기가 있는 쪽 (0 = 띠의 위/왼쪽 면, 1 = 아래/오른쪽 면). 그 면에서부터 파인다.
    public private(set) var sides: [Int]
    private var claims: [Int: Int] = [:]

    public init(pattern: BitePattern = BitePattern()) {
        self.pattern = pattern
        self.eaten = [Double](repeating: 0, count: pattern.cellCount)
        self.sides = [Int](repeating: 0, count: pattern.cellCount)
    }

    /// 스냅샷처럼 이미 `cells`칸만큼 먹힌 상태에서 시작할 때. 먹히는 순서대로 채운다.
    public mutating func preset(cells: Double) {
        var left = min(max(cells, 0), Double(pattern.cellCount))
        for cell in pattern.order {
            let amount = min(left, 1)
            eaten[cell] = amount
            left -= amount
        }
        total = eaten.reduce(0, +)
    }

    /// `index`번 물고기가 맡은 칸. 맡은 칸이 다 먹히면, 아직 아무도 안 맡은 칸 중
    /// 곧 먹힐 순서의 칸 몇 개 가운데 하나를 새로 맡는다. 없으면 nil.
    public mutating func claim<G: RandomNumberGenerator>(forFish index: Int, crew: Int, using generator: inout G) -> Int? {
        if let cell = claims[index], eaten[cell] < 1 { return cell }
        let taken = Set(claims.filter { $0.key != index && eaten[$0.value] < 1 }.values)
        var candidates: [Int] = []
        for cell in pattern.order where eaten[cell] < 1 && !taken.contains(cell) {
            candidates.append(cell)
            if candidates.count >= max(crew, 1) * 2 { break }
        }
        guard let cell = candidates.randomElement(using: &generator) else {
            claims[index] = nil
            return nil
        }
        claims[index] = cell
        return cell
    }

    public mutating func bite(cell: Int, amount: Double, side: Int = 0) {
        guard eaten.indices.contains(cell) else { return }
        sides[cell] = side
        let next = min(eaten[cell] + max(amount, 0), 1)
        total += next - eaten[cell]
        eaten[cell] = next
    }
}
