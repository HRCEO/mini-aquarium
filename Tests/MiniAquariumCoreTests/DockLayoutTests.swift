import CoreGraphics
import Testing
@testable import MiniAquariumCore

@Suite("DockLayout")
struct DockLayoutTests {
    private let screen = CGRect(x: 0, y: 0, width: 1800, height: 1169)

    /// 오른쪽 Dock: 아이콘 줄 위(before)와 아래(after)에 빈 띠가 하나씩 있다.
    private func rightDockRegion() throws -> DockRegion {
        let visible = CGRect(x: 0, y: 0, width: 1742, height: 1130)
        let pill = CGRect(x: 1742, y: 200, width: 58, height: 700)
        return try #require(DockFit.region(screen: screen, visible: visible, dockItems: 12, tile: 48, measuredPill: pill))
    }

    /// 아래쪽 Dock: 아이콘 줄 왼쪽(before)과 오른쪽(after)에 빈 띠가 하나씩 있다.
    private func bottomDockRegion() throws -> DockRegion {
        let visible = CGRect(x: 0, y: 70, width: 1800, height: 1060)
        let pill = CGRect(x: 500, y: 0, width: 800, height: 70)
        return try #require(DockFit.region(screen: screen, visible: visible, dockItems: 10, tile: 48, measuredPill: pill))
    }

    @Test("한쪽만 고르면 패널 하나, 이음새는 없다")
    func singleStrip() throws {
        let region = try rightDockRegion()
        let layout = try #require(DockLayout(region: region, edge: .before))
        let strip = try #require(region.before)
        #expect(layout.panels.count == 1)
        #expect(layout.seam == nil)
        #expect(layout.isVertical)
        #expect(layout.world == strip.size)
        #expect(layout.panels[0].viewport == CGRect(origin: .zero, size: strip.size))
        // 위쪽 띠이므로 띠의 위 모서리에 붙는다
        #expect(layout.panels[0].frame == strip)
    }

    @Test("양쪽이면 두 띠가 이어진 긴 어항이 되고 이음새는 첫 띠의 길이다")
    func bothStripsJoined() throws {
        let region = try rightDockRegion()
        let layout = try #require(DockLayout(region: region, edge: .both))
        let before = try #require(region.before), after = try #require(region.after)
        #expect(layout.panels.count == 2)
        #expect(layout.world.height == before.height + after.height)
        #expect(layout.seam == before.height)
        // 두 번째 패널의 뷰포트는 첫 패널 길이만큼 밀려서 이어진다
        #expect(layout.panels[1].viewport.minY == layout.panels[0].viewport.height)
    }

    @Test("두께는 두 띠 중 얇은 쪽에 맞춘다")
    func thicknessIsMinimum() throws {
        let region = DockRegion(
            side: .right,
            before: CGRect(x: 1742, y: 900, width: 58, height: 200),
            after: CGRect(x: 1742, y: 0, width: 50, height: 300)
        )
        let layout = try #require(DockLayout(region: region, edge: .both))
        #expect(layout.world.width == 50)
        #expect(layout.panels.allSatisfy { $0.frame.width == 50 })
    }

    @Test("세로 Dock의 패널은 아이콘 줄 반대쪽(화면 가장자리 쪽)으로 붙는다")
    func verticalPlacement() throws {
        let region = try rightDockRegion()
        let layout = try #require(DockLayout(region: region, edge: .both))
        let before = try #require(region.before), after = try #require(region.after)
        // 위쪽 띠: 위 모서리에 붙는다 / 아래쪽 띠: 아래 모서리에 붙는다
        #expect(layout.panels[0].frame.maxY == before.maxY)
        #expect(layout.panels[1].frame.minY == after.minY)
    }

    @Test("가로 Dock은 가로로 이어지고 패널은 화면 가장자리 쪽으로 붙는다")
    func horizontalPlacement() throws {
        let region = try bottomDockRegion()
        let layout = try #require(DockLayout(region: region, edge: .both))
        let before = try #require(region.before), after = try #require(region.after)
        #expect(!layout.isVertical)
        #expect(layout.world.width == before.width + after.width)
        #expect(layout.seam == before.width)
        #expect(layout.panels[0].frame.minX == before.minX)
        #expect(layout.panels[1].frame.maxX == after.maxX)
        #expect(layout.panels[1].viewport.minX == layout.panels[0].viewport.width)
    }

    @Test("선택한 쪽에 자리가 없으면 남은 쪽을 쓴다")
    func fallsBackToOtherStrip() throws {
        let only = CGRect(x: 1742, y: 0, width: 58, height: 400)
        let region = DockRegion(side: .right, before: nil, after: only)
        let layout = try #require(DockLayout(region: region, edge: .before))
        #expect(layout.panels.count == 1)
        #expect(layout.panels[0].frame.origin.y == only.minY)
    }

    @Test("빈 자리가 전혀 없으면 nil")
    func noStrips() {
        let region = DockRegion(side: .right, before: nil, after: nil)
        #expect(DockLayout(region: region, edge: .both) == nil)
    }
}
