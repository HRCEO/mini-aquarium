import MiniAquariumCore
import SwiftUI

/// 물고기 벡터 그림. 길이 1짜리 단위 공간에서 오른쪽을 보고 그린다 (y는 아래가 +).
enum FishArt {
    static func draw(_ species: Species, in g: inout GraphicsContext, t: Double, eating: Double) {
        let wag = sin(t * (species == .tetra ? 11 : 7)) * 0.2
        switch species {
        case .goldfish: goldfish(&g, wag)
        case .tetra: tetra(&g, wag)
        case .clownfish: clownfish(&g, wag)
        case .tang: tang(&g, wag)
        case .angelfish: angelfish(&g, wag)
        case .betta: betta(&g, wag, t)
        case .puffer: puffer(&g, wag)
        case .seahorse: seahorse(&g, t)
        case .jellyfish: jellyfish(&g, t)
        case .guppy: guppy(&g, wag)
        case .discus: discus(&g, wag)
        case .koi: koi(&g, wag)
        case .butterflyfish: butterflyfish(&g, wag)
        case .moorishIdol: moorishIdol(&g, wag)
        }
    }

    // MARK: - Shared pieces

    static func pts(_ values: [(Double, Double)]) -> [CGPoint] { values.map { Art.p($0.0, $0.1) } }

    /// 몸통: 그라데이션 채우기 → 클리핑된 무늬 → 테두리.
    static func body(
        _ g: inout GraphicsContext, _ points: [CGPoint], top: Color, bottom: Color,
        edge: Color, decorate: (inout GraphicsContext) -> Void = { _ in }
    ) {
        let path = Art.closedCurve(points)
        let box = path.boundingRect
        g.fill(path, with: Art.vertical(top, bottom, box.minY, box.maxY))
        g.drawLayer { layer in
            layer.clip(to: path)
            decorate(&layer)
            // 윗면 은은한 하이라이트
            layer.fill(
                Art.oval(Art.p(box.midX + 0.04, box.minY + box.height * 0.28), box.width * 0.36, box.height * 0.12),
                with: .color(.white.opacity(0.22))
            )
        }
        g.stroke(path, with: .color(edge), lineWidth: 0.014)
    }

    /// 꼬리나 지느러미: `base`를 축으로 흔들린다. 점은 base 기준 상대 좌표.
    static func fin(
        _ g: inout GraphicsContext, base: CGPoint, angle: Double, _ points: [(Double, Double)],
        fill: GraphicsContext.Shading, edge: Color
    ) {
        g.drawLayer { layer in
            layer.translateBy(x: base.x, y: base.y)
            layer.rotate(by: .radians(angle))
            let path = Art.closedCurve(pts(points))
            layer.fill(path, with: fill)
            layer.stroke(path, with: .color(edge), lineWidth: 0.012)
            // 지느러미 줄기
            let spine = Art.openCurve(pts(points).dropFirst().prefix(max(points.count - 2, 2)).map { $0 })
            layer.stroke(spine, with: .color(edge.opacity(0.35)), lineWidth: 0.006)
        }
    }

    private static func gill(_ g: inout GraphicsContext, x: Double, height: Double, color: Color) {
        let arc = Art.openCurve(pts([(x, -height), (x - 0.04, 0), (x, height)]))
        g.stroke(arc, with: .color(color), lineWidth: 0.012)
    }

    // MARK: - Species

    private static func goldfish(_ g: inout GraphicsContext, _ wag: Double) {
        let orange = Art.c(1, 0.5, 0.1), light = Art.c(1, 0.78, 0.35), edge = Art.c(0.7, 0.3, 0.05)
        let flow = Art.vertical(orange.opacity(0.85), light.opacity(0.5), -0.3, 0.3)
        fin(&g, base: Art.p(0.12, -0.22), angle: wag * 0.3, [(0, 0), (-0.1, -0.2), (-0.28, -0.2), (-0.3, -0.02)], fill: flow, edge: edge)
        fin(&g, base: Art.p(-0.3, 0), angle: wag, [
            (0, 0), (-0.14, -0.22), (-0.38, -0.36), (-0.5, -0.14), (-0.42, 0), (-0.5, 0.15), (-0.38, 0.36), (-0.14, 0.22),
        ], fill: flow, edge: edge)
        body(&g, pts([
            (0.5, 0.03), (0.4, -0.15), (0.14, -0.26), (-0.15, -0.21), (-0.32, -0.07),
            (-0.32, 0.07), (-0.15, 0.22), (0.12, 0.26), (0.36, 0.16),
        ]), top: orange, bottom: light, edge: edge) { layer in
            for i in 0..<5 {
                let x = -0.2 + Double(i) * 0.14
                layer.stroke(Art.openCurve(pts([(x, -0.2), (x + 0.04, 0), (x, 0.2)])), with: .color(edge.opacity(0.18)), lineWidth: 0.01)
            }
        }
        gill(&g, x: 0.22, height: 0.15, color: edge.opacity(0.5))
        fin(&g, base: Art.p(0.12, 0.08), angle: wag * 0.8 + 0.3, [(0, 0), (-0.14, 0.04), (-0.22, 0.14), (-0.08, 0.1)], fill: .color(light.opacity(0.8)), edge: edge)
        Art.eye(&g, at: Art.p(0.36, -0.05), radius: 0.032)
    }

    private static func tetra(_ g: inout GraphicsContext, _ wag: Double) {
        let silver = Art.c(0.5, 0.58, 0.62), belly = Art.c(0.93, 0.94, 0.92), edge = Art.c(0.2, 0.28, 0.35)
        fin(&g, base: Art.p(-0.36, 0), angle: wag, [(0, 0), (-0.13, -0.11), (-0.2, 0), (-0.13, 0.11)], fill: .color(Art.c(0.85, 0.9, 0.9, 0.65)), edge: edge)
        fin(&g, base: Art.p(0.0, 0.1), angle: 0, [(0, 0), (-0.1, 0.1), (-0.16, 0.08), (-0.1, 0)], fill: .color(Art.c(0.9, 0.2, 0.2, 0.6)), edge: edge)
        body(&g, pts([
            (0.5, 0), (0.37, -0.1), (0.1, -0.15), (-0.2, -0.1), (-0.38, -0.03),
            (-0.38, 0.03), (-0.2, 0.1), (0.1, 0.15), (0.37, 0.1),
        ]), top: silver, bottom: belly, edge: edge) { layer in
            layer.fill(Path(CGRect(x: -0.32, y: -0.065, width: 0.8, height: 0.045)), with: .color(Art.c(0.15, 0.9, 1)))
            layer.fill(Path(CGRect(x: -0.42, y: -0.01, width: 0.4, height: 0.2)), with: .color(Art.c(0.95, 0.15, 0.15)))
        }
        Art.eye(&g, at: Art.p(0.38, -0.025), radius: 0.03)
    }

    private static func clownfish(_ g: inout GraphicsContext, _ wag: Double) {
        let orange = Art.c(1, 0.42, 0.06), light = Art.c(1, 0.6, 0.2), ink = Art.c(0.12, 0.08, 0.06)
        fin(&g, base: Art.p(-0.37, 0), angle: wag, [(0, 0), (-0.12, -0.15), (-0.24, -0.1), (-0.24, 0.1), (-0.12, 0.15)], fill: .color(orange), edge: ink)
        fin(&g, base: Art.p(0.18, -0.2), angle: wag * 0.3, [(0, 0), (-0.1, -0.12), (-0.3, -0.1), (-0.34, 0.03)], fill: .color(orange), edge: ink)
        body(&g, pts([
            (0.5, 0.02), (0.38, -0.14), (0.1, -0.22), (-0.18, -0.17), (-0.38, -0.08),
            (-0.38, 0.08), (-0.18, 0.17), (0.1, 0.22), (0.36, 0.14),
        ]), top: orange, bottom: light, edge: ink) { layer in
            for (x, w) in [(0.24, 0.07), (-0.02, 0.1), (-0.3, 0.05)] {
                layer.fill(Path(CGRect(x: x - w / 2 - 0.018, y: -0.3, width: w + 0.036, height: 0.6)), with: .color(ink))
                layer.fill(Path(CGRect(x: x - w / 2, y: -0.3, width: w, height: 0.6)), with: .color(.white))
            }
        }
        fin(&g, base: Art.p(0.14, 0.1), angle: wag + 0.2, [(0, 0), (-0.12, 0.02), (-0.18, 0.12), (-0.06, 0.1)], fill: .color(orange), edge: ink)
        Art.eye(&g, at: Art.p(0.36, -0.05), radius: 0.03)
    }

    private static func tang(_ g: inout GraphicsContext, _ wag: Double) {
        let blue = Art.c(0.08, 0.32, 0.88), light = Art.c(0.3, 0.68, 1), ink = Art.c(0.04, 0.08, 0.3)
        fin(&g, base: Art.p(-0.32, 0), angle: wag, [(0, 0), (-0.12, -0.22), (-0.2, -0.15), (-0.15, 0), (-0.2, 0.15), (-0.12, 0.22)], fill: .color(Art.c(1, 0.85, 0.15)), edge: ink)
        fin(&g, base: Art.p(0.2, -0.27), angle: 0, [(0, 0), (-0.1, -0.1), (-0.4, -0.1), (-0.42, 0.04)], fill: .color(ink.opacity(0.85)), edge: ink)
        fin(&g, base: Art.p(0.1, 0.27), angle: 0, [(0, 0), (-0.1, 0.1), (-0.36, 0.1), (-0.36, -0.02)], fill: .color(ink.opacity(0.85)), edge: ink)
        body(&g, pts([
            (0.48, 0), (0.36, -0.17), (0.1, -0.3), (-0.2, -0.26), (-0.34, -0.08),
            (-0.34, 0.08), (-0.2, 0.26), (0.1, 0.3), (0.36, 0.17),
        ]), top: blue, bottom: light, edge: ink) { layer in
            let palette = Art.openCurve(pts([(0.3, -0.04), (0.08, -0.2), (-0.16, -0.17), (-0.02, 0.0), (-0.22, 0.1), (-0.3, 0.02)]))
            layer.stroke(palette, with: .color(ink), style: StrokeStyle(lineWidth: 0.075, lineCap: .round, lineJoin: .round))
            layer.fill(Art.circle(Art.p(-0.3, 0), 0.04), with: .color(Art.c(1, 0.85, 0.15)))
        }
        Art.eye(&g, at: Art.p(0.34, -0.07), radius: 0.032)
    }

    private static func angelfish(_ g: inout GraphicsContext, _ wag: Double) {
        let silver = Art.c(0.9, 0.88, 0.74), light = Art.c(0.99, 0.98, 0.9), ink = Art.c(0.2, 0.2, 0.25)
        let veil = Art.vertical(Art.c(0.95, 0.85, 0.5, 0.8), Art.c(1, 1, 0.9, 0.4), -0.5, 0.5)
        fin(&g, base: Art.p(0.06, -0.17), angle: wag * 0.2, [(0, 0), (-0.04, -0.28), (-0.18, -0.34), (-0.3, -0.1)], fill: veil, edge: ink.opacity(0.7))
        fin(&g, base: Art.p(0.06, 0.17), angle: -wag * 0.2, [(0, 0), (-0.04, 0.28), (-0.18, 0.34), (-0.3, 0.1)], fill: veil, edge: ink.opacity(0.7))
        fin(&g, base: Art.p(-0.28, 0), angle: wag, [(0, 0), (-0.14, -0.1), (-0.2, 0), (-0.14, 0.1)], fill: veil, edge: ink.opacity(0.7))
        body(&g, pts([
            (0.4, 0), (0.22, -0.14), (0, -0.2), (-0.2, -0.1), (-0.3, 0), (-0.2, 0.1), (0, 0.2), (0.22, 0.14),
        ]), top: silver, bottom: light, edge: ink.opacity(0.7)) { layer in
            for x in [0.22, 0.02, -0.18] {
                layer.fill(Path(CGRect(x: x - 0.02, y: -0.3, width: 0.04, height: 0.6)), with: .color(ink.opacity(0.75)))
            }
        }
        Art.eye(&g, at: Art.p(0.28, -0.03), radius: 0.028, iris: Art.c(0.7, 0.1, 0.1))
    }

    private static func betta(_ g: inout GraphicsContext, _ wag: Double, _ t: Double) {
        let red = Art.c(0.72, 0.04, 0.16), light = Art.c(0.95, 0.25, 0.35), ink = Art.c(0.3, 0.02, 0.1)
        let flow = Art.horizontal(Art.c(0.85, 0.1, 0.3, 0.85), Art.c(0.35, 0.2, 0.85, 0.45), 0, -0.7)
        let ripple = sin(t * 5) * 0.03
        fin(&g, base: Art.p(-0.28, 0), angle: wag * 1.3, [
            (0, 0), (-0.2, -0.3 + ripple), (-0.46, -0.36), (-0.64, -0.12), (-0.68, 0.04),
            (-0.6, 0.22), (-0.44, 0.38 - ripple), (-0.2, 0.28),
        ], fill: flow, edge: ink)
        fin(&g, base: Art.p(0.1, -0.1), angle: wag * 0.4, [(0, 0), (-0.04, -0.2), (-0.26, -0.3 + ripple), (-0.36, -0.06)], fill: flow, edge: ink)
        fin(&g, base: Art.p(0.0, 0.1), angle: -wag * 0.4, [(0, 0), (-0.08, 0.26), (-0.3, 0.34 - ripple), (-0.32, 0.04)], fill: flow, edge: ink)
        body(&g, pts([
            (0.46, 0), (0.34, -0.09), (0.1, -0.12), (-0.15, -0.09), (-0.3, -0.02),
            (-0.3, 0.03), (-0.15, 0.09), (0.1, 0.12), (0.34, 0.08),
        ]), top: red, bottom: light, edge: ink)
        Art.eye(&g, at: Art.p(0.35, -0.025), radius: 0.026)
    }

    private static func puffer(_ g: inout GraphicsContext, _ wag: Double) {
        let olive = Art.c(0.8, 0.7, 0.25), cream = Art.c(1, 0.95, 0.72), ink = Art.c(0.4, 0.3, 0.1)
        fin(&g, base: Art.p(-0.38, 0.02), angle: wag, [(0, 0), (-0.1, -0.1), (-0.17, 0), (-0.1, 0.1)], fill: .color(olive), edge: ink)
        fin(&g, base: Art.p(-0.1, -0.3), angle: wag * 0.6, [(0, 0), (-0.06, -0.1), (-0.18, -0.06), (-0.14, 0.02)], fill: .color(olive), edge: ink)
        body(&g, pts([
            (0.46, 0.04), (0.38, -0.18), (0.14, -0.32), (-0.14, -0.32), (-0.36, -0.16),
            (-0.4, 0.04), (-0.32, 0.22), (-0.1, 0.32), (0.18, 0.3), (0.38, 0.2),
        ]), top: olive, bottom: cream, edge: ink) { layer in
            for i in 0..<12 {
                let x = -0.3 + Art.noise(Double(i)) * 0.6, y = -0.28 + Art.noise(Double(i) + 40) * 0.3
                layer.fill(Art.circle(Art.p(x, y), 0.018 + Art.noise(Double(i) + 9) * 0.014), with: .color(ink.opacity(0.55)))
            }
        }
        fin(&g, base: Art.p(0.1, 0.06), angle: wag * 1.5 + 0.3, [(0, 0), (-0.1, -0.05), (-0.16, 0.04), (-0.08, 0.1)], fill: .color(Art.c(1, 1, 1, 0.7)), edge: ink)
        Art.eye(&g, at: Art.p(0.28, -0.08), radius: 0.05, iris: Art.c(0.1, 0.15, 0.1))
        g.stroke(Art.openCurve(pts([(0.44, 0.08), (0.4, 0.1), (0.36, 0.09)])), with: .color(ink), lineWidth: 0.014)
    }

    private static func seahorse(_ g: inout GraphicsContext, _ t: Double) {
        let amber = Art.c(0.95, 0.62, 0.12), dark = Art.c(0.75, 0.38, 0.08), light = Art.c(1, 0.82, 0.4)
        let sway = sin(t * 2) * 0.02
        let spine = Art.openCurve(pts([
            (-0.02, -0.3), (-0.07, -0.14), (0.04 + sway, 0.04), (0.0, 0.22),
            (-0.1 + sway, 0.36), (-0.22, 0.32), (-0.2, 0.2), (-0.12, 0.2),
        ]))
        g.drawLayer { layer in
            layer.translateBy(x: -0.07, y: -0.04)
            let flutter = sin(t * 14) * 0.15
            layer.rotate(by: .radians(flutter))
            layer.fill(Art.closedCurve(pts([(0, -0.1), (-0.12, -0.12), (-0.18, 0), (-0.12, 0.12), (0, 0.1)])),
                       with: .color(Art.c(1, 0.9, 0.6, 0.6)))
        }
        g.stroke(spine, with: .color(dark), style: StrokeStyle(lineWidth: 0.15, lineCap: .round, lineJoin: .round))
        g.stroke(spine, with: .color(amber), style: StrokeStyle(lineWidth: 0.125, lineCap: .round, lineJoin: .round))
        g.fill(Art.oval(Art.p(0.03, -0.04), 0.1, 0.18), with: Art.vertical(amber, light, -0.2, 0.15))
        for i in 0..<5 {
            let y = -0.16 + Double(i) * 0.07
            g.stroke(Art.openCurve(pts([(-0.06, y), (0.03, y + 0.015), (0.12, y)])), with: .color(dark.opacity(0.45)), lineWidth: 0.008)
        }
        let head = Art.oval(Art.p(0.0, -0.36), 0.105, 0.085)
        g.fill(head, with: .color(amber))
        g.stroke(Art.openCurve(pts([(0.06, -0.37), (0.2, -0.36), (0.3, -0.35)])), with: .color(dark), style: StrokeStyle(lineWidth: 0.065, lineCap: .round))
        g.stroke(Art.openCurve(pts([(0.06, -0.37), (0.2, -0.36), (0.3, -0.35)])), with: .color(amber), style: StrokeStyle(lineWidth: 0.05, lineCap: .round))
        for i in 0..<3 {
            let x = -0.06 + Double(i) * 0.04
            g.fill(Art.circle(Art.p(x, -0.455), 0.017), with: .color(dark))
        }
        Art.eye(&g, at: Art.p(0.03, -0.375), radius: 0.025)
    }

    private static func jellyfish(_ g: inout GraphicsContext, _ t: Double) {
        let pulse = 1 + sin(t * 3) * 0.09
        let ink = Art.c(0.55, 0.35, 0.85)
        for i in 0..<6 {
            let x = -0.22 + Double(i) * 0.088
            let length = 0.42 + Art.noise(Double(i)) * 0.14
            let points = (0...5).map { step -> CGPoint in
                let f = Double(step) / 5
                return Art.p(x + sin(t * 2 + Double(i) + f * 3.2) * 0.05 * f, 0.02 + f * length)
            }
            g.stroke(Art.openCurve(points), with: .color(ink.opacity(0.55)), style: StrokeStyle(lineWidth: 0.02, lineCap: .round))
        }
        for i in 0..<3 {
            let x = -0.1 + Double(i) * 0.1
            let points = (0...4).map { step -> CGPoint in
                let f = Double(step) / 4
                return Art.p(x + sin(t * 1.6 + Double(i) * 2 + f * 3) * 0.05 * f, 0.0 + f * 0.3)
            }
            g.stroke(Art.openCurve(points), with: .color(Art.c(0.95, 0.6, 0.85, 0.7)), style: StrokeStyle(lineWidth: 0.045, lineCap: .round))
        }
        var bell = Path()
        let top = -0.36 * pulse
        bell.move(to: Art.p(-0.34, 0.03))
        bell.addCurve(to: Art.p(0.34, 0.03), control1: Art.p(-0.36, top * 1.35), control2: Art.p(0.36, top * 1.35))
        for i in 0..<6 {
            let x = 0.34 - Double(i + 1) * 0.68 / 6
            bell.addQuadCurve(to: Art.p(x, 0.03), control: Art.p(x + 0.057, 0.09))
        }
        bell.closeSubpath()
        g.fill(bell, with: Art.vertical(Art.c(0.9, 0.65, 1, 0.8), Art.c(0.6, 0.75, 1, 0.5), top, 0.1))
        g.stroke(bell, with: .color(ink.opacity(0.7)), lineWidth: 0.014)
        g.fill(Art.oval(Art.p(-0.08, top * 0.62), 0.12, 0.05), with: .color(.white.opacity(0.4)))
        g.fill(Art.oval(Art.p(0.02, top * 0.25), 0.1, 0.06), with: .color(Art.c(1, 0.7, 0.9, 0.5)))
    }
}
