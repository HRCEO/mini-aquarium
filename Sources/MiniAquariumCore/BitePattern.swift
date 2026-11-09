import Foundation

/// 시간 띠가 사라지는 순서. 띠를 잘게 나눈 칸을 무작위 길이의 덩어리로 묶어 먹으므로,
/// 매번 다른 자리에 구멍이 나고 끊어진다. 타이머마다 새로 만든다.
public struct BitePattern: Equatable {
    public static let defaultCellCount = 96

    /// order[p] = p번째로 먹히는 칸의 위치 (0 = 띠의 시작)
    public let order: [Int]
    /// rank[c] = c번 칸이 먹히는 순번
    public let rank: [Int]

    public var cellCount: Int { order.count }

    public init<G: RandomNumberGenerator>(cellCount: Int = Self.defaultCellCount, using generator: inout G) {
        let count = max(cellCount, 1)
        var taken = [Bool](repeating: false, count: count)
        var order: [Int] = []
        order.reserveCapacity(count)

        func take(_ cell: Int) {
            taken[cell] = true
            order.append(cell)
        }

        while order.count < count {
            let free = taken.indices.filter { !taken[$0] }
            guard let start = free.randomElement(using: &generator) else { break }
            take(start)
            var low = start, high = start
            // 한 입에 1~9칸. 짧게 콕 찍기도, 길게 뜯어먹기도 한다.
            for _ in 1..<Int.random(in: 2...10, using: &generator) {
                let canLow = low > 0 && !taken[low - 1]
                let canHigh = high < count - 1 && !taken[high + 1]
                if !canLow && !canHigh { break }
                if canLow && (!canHigh || Bool.random(using: &generator)) {
                    low -= 1
                    take(low)
                } else {
                    high += 1
                    take(high)
                }
            }
        }

        var rank = [Int](repeating: 0, count: count)
        for (position, cell) in order.enumerated() { rank[cell] = position }
        self.order = order
        self.rank = rank
    }

    public init(cellCount: Int = Self.defaultCellCount) {
        var generator = SystemRandomNumberGenerator()
        self.init(cellCount: cellCount, using: &generator)
    }
}
