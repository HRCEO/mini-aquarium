import MiniAquariumCore
import SwiftUI

/// 나중에 추가한 물고기들의 그림.
extension FishArt {
    static func ellipsePoints(cx: Double, cy: Double, rx: Double, ry: Double, count: Int = 12) -> [(Double, Double)] {
        (0..<count).map { index in
            let angle = Double(index) / Double(count) * 2 * .pi
            return (cx + rx * cos(angle), cy + ry * sin(angle))
        }
    }

    static func guppy(_ g: inout GraphicsContext, _ wag: Double) {
        let teal = Art.c(0.18, 0.66, 0.74), light = Art.c(0.88, 0.96, 0.72), edge = Art.c(0.08, 0.24, 0.34)
        let tail = Art.vertical(Art.c(0.95, 0.25, 0.6, 0.9), Art.c(0.3, 0.4, 0.95, 0.75), -0.32, 0.32)
        fin(&g, base: Art.p(-0.28, 0), angle: wag, [
            (0, 0), (-0.14, -0.3), (-0.4, -0.32), (-0.52, -0.06), (-0.48, 0.12), (-0.36, 0.3), (-0.14, 0.2),
        ], fill: tail, edge: edge)
        body(&g, pts([
            (0.46, 0), (0.34, -0.1), (0.1, -0.16), (-0.15, -0.12), (-0.3, -0.04),
            (-0.3, 0.04), (-0.15, 0.12), (0.1, 0.16), (0.34, 0.1),
        ]), top: teal, bottom: light, edge: edge) { layer in
            for (x, y) in [(-0.08, -0.03), (0.06, 0.04), (-0.2, 0.02)] {
                layer.fill(Art.circle(Art.p(x, y), 0.03), with: .color(Art.c(0.95, 0.3, 0.5, 0.85)))
            }
        }
        fin(&g, base: Art.p(0.0, -0.14), angle: wag * 0.3, [(0, 0), (-0.06, -0.14), (-0.2, -0.12), (-0.18, 0)], fill: .color(Art.c(0.4, 0.5, 0.95, 0.7)), edge: edge)
        Art.eye(&g, at: Art.p(0.34, -0.02), radius: 0.028)
    }

    static func discus(_ g: inout GraphicsContext, _ wag: Double) {
        let red = Art.c(0.9, 0.38, 0.2), gold = Art.c(1, 0.78, 0.4), edge = Art.c(0.5, 0.15, 0.08)
        fin(&g, base: Art.p(-0.3, 0), angle: wag, [(0, 0), (-0.1, -0.12), (-0.18, 0), (-0.1, 0.12)], fill: .color(red.opacity(0.8)), edge: edge)
        fin(&g, base: Art.p(0.2, -0.3), angle: 0, [(0, 0), (-0.1, -0.1), (-0.4, -0.04), (-0.42, 0.06)], fill: .color(red.opacity(0.7)), edge: edge)
        fin(&g, base: Art.p(0.2, 0.3), angle: 0, [(0, 0), (-0.1, 0.1), (-0.4, 0.04), (-0.42, -0.06)], fill: .color(red.opacity(0.7)), edge: edge)
        body(&g, pts(ellipsePoints(cx: 0.05, cy: 0, rx: 0.38, ry: 0.36)), top: red, bottom: gold, edge: edge) { layer in
            for i in 0..<6 {
                let x = -0.25 + Double(i) * 0.1
                layer.stroke(Art.openCurve(pts([(x, -0.34), (x + 0.03, 0), (x, 0.34)])), with: .color(edge.opacity(0.35)), lineWidth: 0.02)
            }
        }
        Art.eye(&g, at: Art.p(0.32, -0.06), radius: 0.032)
    }

    static func koi(_ g: inout GraphicsContext, _ wag: Double) {
        let white = Art.c(0.98, 0.96, 0.92), cream = Art.c(0.9, 0.88, 0.82), edge = Art.c(0.4, 0.3, 0.25)
        let orange = Art.c(0.98, 0.42, 0.1), ink = Art.c(0.12, 0.1, 0.1)
        fin(&g, base: Art.p(-0.38, 0), angle: wag, [(0, 0), (-0.12, -0.16), (-0.3, -0.18), (-0.26, 0), (-0.3, 0.18), (-0.12, 0.16)], fill: .color(white.opacity(0.85)), edge: edge)
        body(&g, pts([
            (0.5, 0.02), (0.4, -0.12), (0.14, -0.19), (-0.2, -0.15), (-0.4, -0.05),
            (-0.4, 0.05), (-0.2, 0.15), (0.14, 0.19), (0.38, 0.12),
        ]), top: white, bottom: cream, edge: edge) { layer in
            layer.fill(Art.oval(Art.p(0.14, -0.06), 0.2, 0.12), with: .color(orange))
            layer.fill(Art.oval(Art.p(-0.16, 0.0), 0.22, 0.14), with: .color(orange))
            layer.fill(Art.oval(Art.p(-0.02, -0.12), 0.08, 0.05), with: .color(ink))
            layer.fill(Art.oval(Art.p(-0.3, 0.06), 0.07, 0.05), with: .color(ink))
        }
        fin(&g, base: Art.p(0.1, 0.12), angle: wag + 0.3, [(0, 0), (-0.12, 0.03), (-0.2, 0.14), (-0.06, 0.1)], fill: .color(white.opacity(0.9)), edge: edge)
        Art.eye(&g, at: Art.p(0.38, -0.04), radius: 0.028)
    }

    static func butterflyfish(_ g: inout GraphicsContext, _ wag: Double) {
        let yellow = Art.c(1, 0.85, 0.15), pale = Art.c(1, 0.96, 0.7), ink = Art.c(0.1, 0.1, 0.12), edge = Art.c(0.5, 0.4, 0.05)
        fin(&g, base: Art.p(-0.3, 0), angle: wag, [(0, 0), (-0.1, -0.14), (-0.16, 0), (-0.1, 0.14)], fill: .color(yellow.opacity(0.9)), edge: edge)
        body(&g, pts([
            (0.54, 0.04), (0.38, -0.12), (0.14, -0.3), (-0.12, -0.28), (-0.3, -0.1),
            (-0.3, 0.1), (-0.12, 0.28), (0.14, 0.3), (0.38, 0.14),
        ]), top: yellow, bottom: pale, edge: edge) { layer in
            layer.fill(Path(CGRect(x: 0.27, y: -0.4, width: 0.07, height: 0.8)), with: .color(ink))
            layer.fill(Path(CGRect(x: -0.34, y: -0.4, width: 0.07, height: 0.8)), with: .color(ink))
            for i in 0..<4 {
                let y = -0.16 + Double(i) * 0.1
                layer.stroke(Art.openCurve(pts([(-0.2, y), (0.1, y + 0.05), (0.22, y)])), with: .color(edge.opacity(0.25)), lineWidth: 0.012)
            }
        }
        fin(&g, base: Art.p(0.1, -0.28), angle: 0, [(0, 0), (-0.08, -0.1), (-0.3, -0.08), (-0.3, 0.02)], fill: .color(yellow), edge: edge)
        Art.eye(&g, at: Art.p(0.38, -0.02), radius: 0.03)
    }

    static func moorishIdol(_ g: inout GraphicsContext, _ wag: Double) {
        let white = Art.c(0.98, 0.98, 0.96), pale = Art.c(1, 0.93, 0.6), ink = Art.c(0.08, 0.08, 0.1), yellow = Art.c(1, 0.82, 0.1)
        fin(&g, base: Art.p(0.0, -0.3), angle: wag * 0.2, [(0, 0), (-0.1, -0.14), (-0.5, -0.46), (-0.3, -0.1), (-0.26, 0)], fill: .color(white), edge: ink)
        fin(&g, base: Art.p(-0.28, 0), angle: wag, [(0, 0), (-0.1, -0.14), (-0.2, 0), (-0.1, 0.14)], fill: .color(ink.opacity(0.9)), edge: ink)
        body(&g, pts([
            (0.54, 0.05), (0.36, -0.16), (0.1, -0.33), (-0.18, -0.28), (-0.3, -0.08),
            (-0.3, 0.08), (-0.18, 0.28), (0.1, 0.33), (0.34, 0.2),
        ]), top: white, bottom: pale, edge: ink) { layer in
            layer.fill(Path(CGRect(x: 0.14, y: -0.4, width: 0.1, height: 0.8)), with: .color(ink))
            layer.fill(Path(CGRect(x: -0.16, y: -0.4, width: 0.12, height: 0.8)), with: .color(ink))
            layer.fill(Path(CGRect(x: -0.04, y: -0.4, width: 0.18, height: 0.8)), with: .color(yellow))
            layer.fill(Art.oval(Art.p(0.46, 0.05), 0.06, 0.05), with: .color(Art.c(1, 0.6, 0.2)))
        }
        Art.eye(&g, at: Art.p(0.34, -0.06), radius: 0.028)
    }
}
