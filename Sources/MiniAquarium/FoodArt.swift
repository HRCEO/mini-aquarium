import MiniAquariumCore
import SwiftUI

/// 먹이 알갱이 그림. 원점이 먹이 위치.
enum FoodArt {
    static func draw(_ food: Food, in g: inout GraphicsContext) {
        let r = Double(food.kind.radius)
        let spin = food.age * (1.5 + food.seed * 2) + food.seed * 6
        g.drawLayer { layer in
            layer.translateBy(x: food.pos.x, y: food.pos.y)
            let size = 0.4 + 0.6 * max(0, food.remaining)   // 갉을수록 작아진다
            layer.scaleBy(x: size, y: size)
            layer.rotate(by: .radians(spin))
            switch food.kind {
            case .flakes: flake(&layer, r, food.seed)
            case .pellets: pellet(&layer, r)
            case .shrimp: shrimp(&layer, r)
            case .algae: wafer(&layer, r)
            }
        }
    }

    private static func flake(_ g: inout GraphicsContext, _ r: Double, _ seed: Double) {
        let tone = seed < 0.5 ? Art.c(1, 0.72, 0.25) : Art.c(0.95, 0.4, 0.28)
        let shape = Art.closedCurve([Art.p(-r * 1.3, 0), Art.p(-r * 0.2, -r * 0.9), Art.p(r * 1.2, -r * 0.2), Art.p(r * 0.3, r * 0.8)])
        g.fill(shape, with: .color(tone.opacity(0.92)))
        g.stroke(shape, with: .color(.white.opacity(0.5)), lineWidth: 0.4)
    }

    private static func pellet(_ g: inout GraphicsContext, _ r: Double) {
        let ball = Art.circle(.zero, r)
        g.fill(ball, with: .radialGradient(Gradient(colors: [Art.c(0.98, 0.72, 0.38), Art.c(0.72, 0.38, 0.14)]), center: Art.p(-r * 0.3, -r * 0.3), startRadius: 0, endRadius: r * 1.4))
        g.fill(Art.circle(Art.p(-r * 0.35, -r * 0.4), r * 0.28), with: .color(.white.opacity(0.6)))
    }

    private static func shrimp(_ g: inout GraphicsContext, _ r: Double) {
        let curve = Art.openCurve([Art.p(-r * 1.3, r * 0.5), Art.p(-r * 0.5, -r * 0.7), Art.p(r * 0.6, -r * 0.7), Art.p(r * 1.3, r * 0.4)])
        g.stroke(curve, with: .color(Art.c(0.9, 0.42, 0.34)), style: StrokeStyle(lineWidth: r * 0.9, lineCap: .round))
        for i in 0..<4 {
            let x = -r * 0.6 + Double(i) * r * 0.45
            g.stroke(Art.openCurve([Art.p(x, -r * 0.95), Art.p(x, -r * 0.35)]), with: .color(Art.c(1, 0.8, 0.7, 0.8)), lineWidth: 0.6)
        }
        g.fill(Art.circle(Art.p(-r * 1.2, r * 0.45), r * 0.2), with: .color(.black.opacity(0.7)))
    }

    private static func wafer(_ g: inout GraphicsContext, _ r: Double) {
        let disc = Path(roundedRect: CGRect(x: -r, y: -r * 0.8, width: r * 2, height: r * 1.6), cornerRadius: r * 0.35)
        g.fill(disc, with: Art.vertical(Art.c(0.35, 0.65, 0.3), Art.c(0.15, 0.4, 0.2), -r, r))
        for i in 0..<3 {
            let y = -r * 0.45 + Double(i) * r * 0.45
            g.stroke(Art.openCurve([Art.p(-r * 0.8, y), Art.p(r * 0.8, y)]), with: .color(Art.c(0.08, 0.28, 0.12, 0.6)), lineWidth: 0.6)
        }
        g.stroke(disc, with: .color(.white.opacity(0.35)), lineWidth: 0.5)
    }
}
