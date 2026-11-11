import MiniAquariumCore
import SwiftUI

/// 바닥 생물(게) 벡터 그림. 원점은 발이 닿는 바닥 중앙, 위쪽이 -y.
enum CritterArt {
    /// 소품 배율에 더 곱해, 게가 소품보다 작게 보이게 한다.
    static let sizeFactor: CGFloat = 0.75

    private static let stepRate = 14.0   // 게 다리가 움직이는 박자

    static func draw(_ critter: Critter, in g: inout GraphicsContext, t: Double) {
        draw(critter.kind, in: &g, gait: critter.gait, isMoving: critter.isMoving,
             facingRight: critter.facingRight, t: t, phase: critter.phase)
    }

    /// 설정 미리보기처럼 개체 없이 그릴 때도 쓴다.
    static func draw(_ kind: CritterKind, in g: inout GraphicsContext, gait: Double, isMoving: Bool,
                     facingRight: Bool, t: Double, phase: Double) {
        switch kind {
        case .crab:
            crab(&g, gait: gait, isMoving: isMoving, t: t, phase: phase)   // 옆으로 걷는 생물이라 좌우 반전이 없다
        }
    }

    // MARK: - Crab

    private static func crab(_ g: inout GraphicsContext, gait: Double, isMoving: Bool, t: Double, phase: Double) {
        let shell = Art.c(0.88, 0.30, 0.22)
        let dark = Art.c(0.62, 0.17, 0.13)
        let light = Art.c(0.98, 0.55, 0.40)

        for side in [-1.0, 1.0] {
            for index in 0..<3 {
                let k = Double(index)
                let beat = sin(gait * stepRate + k * 2.1 + (side > 0 ? .pi : 0))
                let swing = isMoving ? beat * 2.2 : 0
                let lift = isMoving ? max(0, beat) * 1.6 : 0
                var leg = Path()
                leg.move(to: Art.p(side * (4 + k * 1.5), -4.5))
                leg.addLine(to: Art.p(side * (8.5 + k * 1.6), -7.5 - lift))
                leg.addLine(to: Art.p(side * (10.5 + k * 2) + swing, -0.4 - lift))
                g.stroke(leg, with: .color(dark), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
        }

        for side in [-1.0, 1.0] {
            // 쉴 때는 집게를 살살 흔든다.
            let wave = isMoving ? 0 : sin(t * 2.2 + phase + (side > 0 ? 0 : 1.7)) * 0.35
            let shoulder = Art.p(side * 6.5, -8)
            let claw = Art.p(side * 10.5, -14.5 - wave * 2.5)
            var arm = Path()
            arm.move(to: shoulder)
            arm.addLine(to: claw)
            g.stroke(arm, with: .color(shell), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
            g.fill(Art.oval(claw, 3.6, 2.9), with: .color(light))
            g.stroke(Art.oval(claw, 3.6, 2.9), with: .color(dark), lineWidth: 0.7)
            var notch = Path()
            notch.move(to: Art.p(claw.x - side * 0.2, claw.y - 3))
            notch.addLine(to: Art.p(claw.x - side * 1.7, claw.y - 0.5))
            notch.addLine(to: Art.p(claw.x + side * 1.0, claw.y - 0.3))
            notch.closeSubpath()
            g.fill(notch, with: .color(dark))
        }

        let body = Art.oval(Art.p(0, -6), 8, 5)
        g.fill(body, with: Art.vertical(light, shell, -11, -1))
        g.stroke(body, with: .color(dark), lineWidth: 0.8)
        g.fill(Art.oval(Art.p(-2.5, -8), 2.6, 1.3), with: .color(.white.opacity(0.28)))

        for side in [-1.0, 1.0] {
            var stalk = Path()
            stalk.move(to: Art.p(side * 2.5, -10))
            stalk.addLine(to: Art.p(side * 3, -13))
            g.stroke(stalk, with: .color(dark), style: StrokeStyle(lineWidth: 1, lineCap: .round))
            Art.eye(&g, at: Art.p(side * 3, -13.6), radius: 1.3)
        }
    }
}
