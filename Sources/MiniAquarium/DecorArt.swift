import MiniAquariumCore
import SwiftUI

/// 인테리어 소품 벡터 그림. 원점은 바닥 중앙, 위쪽이 -y.
enum DecorArt {
    static func draw(_ decor: Decor, in g: inout GraphicsContext, t: Double) {
        let h = Double(decor.height)
        switch decor {
        case .kelp: kelp(&g, h, t)
        case .branchCoral: branchCoral(&g, h, t)
        case .fanCoral: fanCoral(&g, h, t)
        case .anemone: anemone(&g, h, t)
        case .cave: cave(&g, h, t)
        case .castle: castle(&g, h)
        case .rockPile: rockPile(&g, h)
        case .chest: chest(&g, h)
        case .driftwood: driftwood(&g, h)
        case .starfish: starfish(&g, h)
        case .shells: shells(&g, h)
        case .bubbler: bubbler(&g, h, t)
        }
    }

    private static func pts(_ values: [(Double, Double)]) -> [CGPoint] { values.map { Art.p($0.0, $0.1) } }

    // MARK: - Plants

    private static func kelp(_ g: inout GraphicsContext, _ h: Double, _ t: Double) {
        let greens = [Art.c(0.12, 0.45, 0.22), Art.c(0.2, 0.58, 0.28), Art.c(0.3, 0.68, 0.32)]
        for strand in 0..<3 {
            let dx = Double(strand - 1) * 9
            let height = h * (0.7 + 0.15 * Double(strand == 1 ? 1 : 0) + Art.noise(Double(strand)) * 0.15)
            let points = (0...6).map { step -> CGPoint in
                let f = Double(step) / 6
                let sway = sin(t * 1.3 + Double(strand) * 1.7 + f * 2.4) * 7 * f
                return Art.p(dx + sway, -f * height)
            }
            let curve = Art.openCurve(points)
            g.stroke(curve, with: .color(greens[strand]), style: StrokeStyle(lineWidth: 4.2, lineCap: .round))
            for (index, point) in points.enumerated().dropFirst() where index % 2 == 0 {
                let side: Double = index % 4 == 0 ? 1 : -1
                let leaf = Art.oval(Art.p(point.x + side * 4, point.y), 4.5, 2)
                g.fill(leaf, with: .color(greens[(strand + 1) % 3].opacity(0.9)))
            }
        }
    }

    private static func branchCoral(_ g: inout GraphicsContext, _ h: Double, _ t: Double) {
        let base = Art.c(0.93, 0.38, 0.42)
        func branch(_ from: CGPoint, _ angle: Double, _ length: Double, _ width: Double, _ depth: Int, _ seed: Double) {
            let sway = sin(t * 0.9 + seed) * 0.03 * Double(4 - depth)
            let to = Art.p(from.x + sin(angle + sway) * length, from.y - cos(angle + sway) * length)
            var segment = Path()
            segment.move(to: from)
            segment.addLine(to: to)
            let tone = Art.c(0.93 + Double(depth) * 0.015, 0.38 + Double(depth) * 0.1, 0.42 + Double(depth) * 0.06)
            g.stroke(segment, with: .color(tone), style: StrokeStyle(lineWidth: width, lineCap: .round))
            guard depth > 0 else {
                g.fill(Art.circle(to, width * 0.75), with: .color(Art.c(1, 0.85, 0.75)))
                return
            }
            branch(to, angle - 0.55, length * 0.72, width * 0.7, depth - 1, seed + 1)
            branch(to, angle + 0.5, length * 0.72, width * 0.7, depth - 1, seed + 2)
            if depth == 3 { branch(to, angle + 0.05, length * 0.6, width * 0.65, depth - 1, seed + 3) }
        }
        g.fill(Art.oval(Art.p(0, -1), 12, 4), with: .color(base.opacity(0.8)))
        branch(Art.p(0, -1), 0, h * 0.34, 5, 3, 0)
    }

    private static func fanCoral(_ g: inout GraphicsContext, _ h: Double, _ t: Double) {
        let tone = Art.c(0.66, 0.3, 0.7)
        let sway = sin(t * 0.8) * 0.04
        g.drawLayer { layer in
            layer.translateBy(x: 0, y: -2)
            layer.rotate(by: .radians(sway))
            var fan = Path()
            fan.move(to: .zero)
            for step in 0...12 {
                let a = (Double(step) / 12 - 0.5) * 2.5
                fan.addLine(to: Art.p(sin(a) * h * 0.55, -cos(a) * h * (0.82 + 0.06 * sin(Double(step) * 2.2))))
            }
            fan.closeSubpath()
            layer.fill(fan, with: Art.vertical(tone.opacity(0.35), Art.c(0.9, 0.5, 0.85, 0.2), -h, 0))
            for ray in 0...10 {
                let a = (Double(ray) / 10 - 0.5) * 2.5
                var line = Path()
                line.move(to: .zero)
                line.addLine(to: Art.p(sin(a) * h * 0.55, -cos(a) * h * 0.85))
                layer.stroke(line, with: .color(tone), lineWidth: 1.1)
            }
            for ring in 1...4 {
                let radius = Double(ring) / 4.4
                let arc = Art.openCurve((0...10).map { step -> CGPoint in
                    let a = (Double(step) / 10 - 0.5) * 2.5
                    return Art.p(sin(a) * h * 0.55 * radius, -cos(a) * h * 0.85 * radius)
                })
                layer.stroke(arc, with: .color(tone.opacity(0.7)), lineWidth: 0.7)
            }
            layer.stroke(Art.openCurve(pts([(0, 0), (0, 4)])), with: .color(tone), lineWidth: 5)
        }
    }

    private static func anemone(_ g: inout GraphicsContext, _ h: Double, _ t: Double) {
        let body = Art.c(0.85, 0.35, 0.6), tip = Art.c(1, 0.85, 0.5)
        for index in 0..<15 {
            let f = Double(index) / 14
            let baseX = (f - 0.5) * 22
            let lean = (f - 0.5) * 1.1
            let length = h * (0.68 + 0.25 * Art.noise(Double(index) + 3))
            let points = (0...4).map { step -> CGPoint in
                let s = Double(step) / 4
                let wave = sin(t * 2.2 + Double(index) * 0.8 + s * 2.4) * 3.2 * s
                return Art.p(baseX + sin(lean) * length * s + wave, -4 - cos(lean) * length * s)
            }
            let curve = Art.openCurve(points)
            g.stroke(curve, with: .color(body), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
            g.fill(Art.circle(points[4], 2.2), with: .color(tip))
        }
        g.fill(Art.closedCurve(pts([(-13, 0), (-10, -8), (0, -11), (10, -8), (13, 0), (0, 3)])), with: Art.vertical(body, Art.c(0.6, 0.2, 0.45), -11, 3))
    }

    // MARK: - Structures

    private static func cave(_ g: inout GraphicsContext, _ h: Double, _ t: Double) {
        let rockTop = Art.c(0.55, 0.5, 0.46), rockBottom = Art.c(0.34, 0.31, 0.3)
        let outer = Art.closedCurve(pts([
            (-0.6 * h, 0), (-0.55 * h, -0.4 * h), (-0.28 * h, -0.82 * h), (0.1 * h, -0.95 * h),
            (0.45 * h, -0.62 * h), (0.62 * h, 0),
        ]))
        g.fill(outer, with: Art.vertical(rockTop, rockBottom, -h, 0))
        g.stroke(outer, with: .color(Art.c(0.2, 0.18, 0.18, 0.6)), lineWidth: 1)
        for i in 0..<7 {
            let x = (-0.4 + Art.noise(Double(i)) * 0.8) * h, y = -(0.15 + Art.noise(Double(i) + 5) * 0.65) * h
            g.fill(Art.oval(Art.p(x, y), 4 + Art.noise(Double(i) + 9) * 4, 2.6), with: .color(.black.opacity(0.1)))
        }
        let mouth = Art.closedCurve(pts([(-0.3 * h, 0), (-0.28 * h, -0.28 * h), (0.0, -0.5 * h), (0.28 * h, -0.28 * h), (0.3 * h, 0)]))
        g.fill(mouth, with: Art.vertical(Art.c(0.05, 0.08, 0.12), Art.c(0.12, 0.14, 0.18), -0.5 * h, 0))
        let blink = (sin(t * 0.7) > 0.93) ? 0.2 : 1.0
        for side in [-1.0, 1.0] {
            g.fill(Art.oval(Art.p(side * 0.08 * h, -0.2 * h), 2.6, 2.6 * blink), with: .color(Art.c(1, 0.95, 0.6)))
        }
        g.fill(Art.oval(Art.p(0, 1), 0.7 * h, 3), with: .color(.black.opacity(0.12)))
    }

    private static func castle(_ g: inout GraphicsContext, _ h: Double) {
        let stone = Art.c(0.78, 0.76, 0.72), dark = Art.c(0.55, 0.53, 0.52), roof = Art.c(0.75, 0.25, 0.25)
        func tower(_ x: Double, _ width: Double, _ height: Double, cone: Bool) {
            g.fill(Path(CGRect(x: x - width / 2, y: -height, width: width, height: height)), with: Art.horizontal(stone, dark, x - width / 2, x + width / 2))
            if cone {
                g.fill(Art.closedCurve(pts([(x - width * 0.62, -height), (x, -height - 14), (x + width * 0.62, -height)])), with: .color(roof))
            } else {
                for i in 0..<3 {
                    g.fill(Path(CGRect(x: x - width / 2 + Double(i) * width / 3 + 0.5, y: -height - 4, width: width / 3 - 1, height: 4)), with: .color(stone))
                }
            }
            g.fill(Path(CGRect(x: x - 1.4, y: -height * 0.7, width: 2.8, height: 6)), with: .color(.black.opacity(0.55)))
        }
        tower(-18, 14, h * 0.8, cone: true)
        tower(18, 14, h * 0.8, cone: true)
        tower(0, 26, h * 0.62, cone: false)
        var door = Path()
        door.move(to: Art.p(-5, 0))
        door.addLine(to: Art.p(-5, -10))
        door.addArc(center: Art.p(0, -10), radius: 5, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        door.addLine(to: Art.p(5, 0))
        door.closeSubpath()
        g.fill(door, with: .color(Art.c(0.2, 0.12, 0.08)))
        g.stroke(Art.openCurve(pts([(18, -h * 0.8 - 14), (18, -h * 0.8 - 22)])), with: .color(dark), lineWidth: 1)
        g.fill(Art.closedCurve(pts([(18, -h * 0.8 - 22), (25, -h * 0.8 - 20), (18, -h * 0.8 - 17)])), with: .color(Art.c(0.95, 0.8, 0.2)))
    }

    private static func rockPile(_ g: inout GraphicsContext, _ h: Double) {
        let blobs: [(Double, Double, Double, Double, Double)] = [
            (-9, -h * 0.28, 15, h * 0.3, 0.50), (8, -h * 0.25, 13, h * 0.27, 0.42), (0, -h * 0.58, 10, h * 0.25, 0.58),
        ]
        for (x, y, rx, ry, tone) in blobs {
            let rock = Art.oval(Art.p(x, y), rx, ry)
            g.fill(rock, with: Art.vertical(Art.c(tone + 0.12, tone + 0.1, tone + 0.08), Art.c(tone - 0.14, tone - 0.15, tone - 0.14), y - ry, y + ry))
            g.stroke(rock, with: .color(.black.opacity(0.25)), lineWidth: 0.8)
        }
    }

    private static func chest(_ g: inout GraphicsContext, _ h: Double) {
        let wood = Art.c(0.55, 0.32, 0.14), dark = Art.c(0.32, 0.18, 0.08), gold = Art.c(0.95, 0.77, 0.25)
        let box = Path(roundedRect: CGRect(x: -14, y: -h * 0.55, width: 28, height: h * 0.55), cornerRadius: 2)
        g.fill(box, with: Art.vertical(wood, dark, -h * 0.55, 0))
        var lid = Path()
        lid.move(to: Art.p(-14, -h * 0.55))
        lid.addQuadCurve(to: Art.p(14, -h * 0.55), control: Art.p(0, -h * 1.15))
        lid.closeSubpath()
        g.fill(lid, with: Art.vertical(Art.c(0.65, 0.4, 0.18), wood, -h, -h * 0.55))
        g.stroke(box, with: .color(dark), lineWidth: 1)
        g.stroke(lid, with: .color(dark), lineWidth: 1)
        for x in [-9.0, 9.0] {
            g.fill(Path(CGRect(x: x - 1.6, y: -h * 0.85, width: 3.2, height: h * 0.85)), with: .color(gold.opacity(0.9)))
        }
        g.fill(Path(roundedRect: CGRect(x: -3, y: -h * 0.66, width: 6, height: 7), cornerRadius: 1.4), with: .color(gold))
        g.fill(Art.circle(Art.p(0, -h * 0.6), 1), with: .color(dark))
    }

    private static func driftwood(_ g: inout GraphicsContext, _ h: Double) {
        let wood = Art.c(0.5, 0.36, 0.24), light = Art.c(0.68, 0.52, 0.36)
        let main = Art.openCurve(pts([(-24, 0), (-14, -h * 0.32), (-2, -h * 0.5), (10, -h * 0.42), (22, -h * 0.7)]))
        g.stroke(main, with: .color(wood.opacity(0.9)), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
        g.stroke(main, with: .color(light), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: [6, 5]))
        let twig = Art.openCurve(pts([(-4, -h * 0.48), (-8, -h * 0.78), (-16, -h * 0.95)]))
        g.stroke(twig, with: .color(wood), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        g.fill(Art.circle(Art.p(22, -h * 0.7), 3.4), with: .color(Art.c(0.35, 0.24, 0.15)))
    }

    private static func starfish(_ g: inout GraphicsContext, _ h: Double) {
        let radius = h * 0.55
        var star = Path()
        for i in 0..<10 {
            let r = i % 2 == 0 ? radius : radius * 0.45
            let a = -Double.pi / 2 + Double(i) * Double.pi / 5
            let point = Art.p(sin(a + .pi / 2) * r * 1.0, -radius * 0.7 + cos(a + .pi / 2) * r * 0.55 * -1)
            if i == 0 { star.move(to: point) } else { star.addLine(to: point) }
        }
        star.closeSubpath()
        g.fill(star, with: Art.vertical(Art.c(1, 0.62, 0.3), Art.c(0.9, 0.38, 0.22), -h, 0))
        g.stroke(star, with: .color(Art.c(0.7, 0.28, 0.15)), style: StrokeStyle(lineWidth: 0.9, lineJoin: .round))
        for i in 0..<5 {
            let a = Double(i) * 2 * .pi / 5
            g.fill(Art.circle(Art.p(sin(a) * radius * 0.55, -radius * 0.7 - cos(a) * radius * 0.3), 0.9), with: .color(Art.c(1, 0.9, 0.7)))
        }
    }

    private static func shells(_ g: inout GraphicsContext, _ h: Double) {
        for (index, x) in [-7.0, 6.0].enumerated() {
            let size = index == 0 ? h * 0.7 : h * 0.55
            g.drawLayer { layer in
                layer.translateBy(x: x, y: 0)
                layer.rotate(by: .degrees(index == 0 ? -8 : 12))
                var shell = Path()
                shell.move(to: Art.p(0, 0))
                shell.addCurve(to: Art.p(0, 0), control1: Art.p(-size, -size * 1.5), control2: Art.p(size, -size * 1.5))
                layer.fill(shell, with: Art.vertical(Art.c(1, 0.88, 0.82), Art.c(0.93, 0.62, 0.62), -size * 1.1, 0))
                layer.stroke(shell, with: .color(Art.c(0.7, 0.4, 0.4)), lineWidth: 0.8)
                for ray in -2...2 {
                    var line = Path()
                    line.move(to: .zero)
                    line.addLine(to: Art.p(Double(ray) * size * 0.28, -size * (1.05 - abs(Double(ray)) * 0.15)))
                    layer.stroke(line, with: .color(Art.c(0.75, 0.45, 0.45, 0.7)), lineWidth: 0.6)
                }
            }
        }
    }

    private static func bubbler(_ g: inout GraphicsContext, _ h: Double, _ t: Double) {
        g.fill(Path(roundedRect: CGRect(x: -6, y: -h * 0.6, width: 12, height: h * 0.6), cornerRadius: 3), with: Art.vertical(Art.c(0.7, 0.7, 0.72), Art.c(0.42, 0.42, 0.45), -h, 0))
        for i in 0..<7 {
            let life = (t * 0.35 + Double(i) / 7).truncatingRemainder(dividingBy: 1)
            let rise = life * 150
            let x = sin(t * 2.4 + Double(i) * 1.9) * (2 + life * 5)
            let radius = 1.2 + life * 2.4 + Art.noise(Double(i)) * 1
            let bubble = Art.circle(Art.p(x, -h * 0.6 - rise), radius)
            g.fill(bubble, with: .color(.white.opacity(0.18)))
            g.stroke(bubble, with: .color(.white.opacity(0.7)), lineWidth: 0.7)
            g.fill(Art.circle(Art.p(x - radius * 0.3, -h * 0.6 - rise - radius * 0.3), radius * 0.25), with: .color(.white.opacity(0.8)))
        }
    }
}
