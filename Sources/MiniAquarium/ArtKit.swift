import SwiftUI

/// 벡터 그림용 작은 도구 모음. 좌표는 호출하는 쪽의 로컬 공간이다.
enum Art {
    static func c(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> Color {
        Color(red: r, green: g, blue: b, opacity: a)
    }

    static func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }

    /// Catmull-Rom 스플라인으로 만든 부드러운 닫힌 곡선.
    static func closedCurve(_ pts: [CGPoint]) -> Path {
        let n = pts.count
        guard n >= 3 else { return Path() }
        var path = Path()
        path.move(to: pts[0])
        for i in 0..<n {
            let (p0, p1, p2, p3) = (pts[(i + n - 1) % n], pts[i], pts[(i + 1) % n], pts[(i + 2) % n])
            path.addCurve(to: p2, control1: control(p1, p0, p2, 1), control2: control(p2, p1, p3, -1))
        }
        path.closeSubpath()
        return path
    }

    /// 끝점이 고정된 열린 곡선.
    static func openCurve(_ pts: [CGPoint]) -> Path {
        guard pts.count >= 2 else { return Path() }
        var path = Path()
        path.move(to: pts[0])
        for i in 0..<(pts.count - 1) {
            let p0 = pts[max(i - 1, 0)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[min(i + 2, pts.count - 1)]
            path.addCurve(to: p2, control1: control(p1, p0, p2, 1), control2: control(p2, p1, p3, -1))
        }
        return path
    }

    /// `anchor` 점의 접선 방향 제어점. sign=1이면 앞쪽, -1이면 뒤쪽 제어점.
    private static func control(_ anchor: CGPoint, _ before: CGPoint, _ after: CGPoint, _ sign: CGFloat) -> CGPoint {
        // Catmull-Rom: c1 = p1 + (p2 - p0)/6, c2 = p2 - (p3 - p1)/6
        if sign > 0 {
            return CGPoint(x: anchor.x + (after.x - before.x) / 6, y: anchor.y + (after.y - before.y) / 6)
        }
        return CGPoint(x: anchor.x - (after.x - before.x) / 6, y: anchor.y - (after.y - before.y) / 6)
    }

    static func vertical(_ top: Color, _ bottom: Color, _ y0: Double, _ y1: Double) -> GraphicsContext.Shading {
        .linearGradient(Gradient(colors: [top, bottom]), startPoint: p(0, y0), endPoint: p(0, y1))
    }

    static func horizontal(_ left: Color, _ right: Color, _ x0: Double, _ x1: Double) -> GraphicsContext.Shading {
        .linearGradient(Gradient(colors: [left, right]), startPoint: p(x0, 0), endPoint: p(x1, 0))
    }

    static func circle(_ center: CGPoint, _ radius: Double) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    static func oval(_ center: CGPoint, _ rx: Double, _ ry: Double) -> Path {
        Path(ellipseIn: CGRect(x: center.x - rx, y: center.y - ry, width: rx * 2, height: ry * 2))
    }

    static func eye(_ g: inout GraphicsContext, at center: CGPoint, radius: Double, iris: Color = .black) {
        g.fill(circle(center, radius * 1.25), with: .color(.white))
        g.fill(circle(center, radius * 0.85), with: .color(iris))
        g.fill(circle(CGPoint(x: center.x + radius * 0.3, y: center.y - radius * 0.3), radius * 0.3), with: .color(.white))
    }

    /// 0..<1 사이의 결정적 의사 난수.
    static func noise(_ seed: Double) -> Double {
        let value = sin(seed * 12.9898 + 78.233) * 43758.5453
        return value - value.rounded(.down)
    }
}
