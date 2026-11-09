import SwiftUI

/// 이어 붙인 어항의 끊어진 단면에 그리는 포털. 물에 비친 얕은 빛의 구멍처럼 어항 안에 머문다.
enum PortalOverlay {
    static func draw(in context: inout GraphicsContext, size: CGSize, edge: Edge, time: Double) {
        let horizontalEdge = edge == .top || edge == .bottom
        let along = horizontalEdge ? size.width : size.height
        let depth = min(along * 0.22, horizontalEdge ? size.height : size.width)
        let rect: CGRect
        let start: CGPoint, end: CGPoint
        switch edge {
        case .bottom:
            rect = CGRect(x: 0, y: size.height - depth, width: size.width, height: depth * 2)
            start = CGPoint(x: size.width / 2, y: size.height); end = CGPoint(x: size.width / 2, y: size.height - depth)
        case .top:
            rect = CGRect(x: 0, y: -depth, width: size.width, height: depth * 2)
            start = CGPoint(x: size.width / 2, y: 0); end = CGPoint(x: size.width / 2, y: depth)
        case .trailing:
            rect = CGRect(x: size.width - depth, y: 0, width: depth * 2, height: size.height)
            start = CGPoint(x: size.width, y: size.height / 2); end = CGPoint(x: size.width - depth, y: size.height / 2)
        case .leading:
            rect = CGRect(x: -depth, y: 0, width: depth * 2, height: size.height)
            start = CGPoint(x: 0, y: size.height / 2); end = CGPoint(x: depth, y: size.height / 2)
        }
        drawRim(in: &context, size: size, edge: edge)
        let oval = Path(ellipseIn: rect)
        let pulse = 0.5 + 0.5 * sin(time * 2.2)

        context.fill(oval, with: .linearGradient(
            Gradient(colors: [Color(red: 0.03, green: 0.14, blue: 0.32).opacity(0.85), Color(red: 0.2, green: 0.5, blue: 0.8).opacity(0.25)]),
            startPoint: start, endPoint: end))
        context.drawLayer { layer in
            layer.clip(to: oval)
            let ring = Path(ellipseIn: rect.insetBy(dx: along * 0.1, dy: along * 0.1))
            layer.stroke(ring, with: .color(.white.opacity(0.14 + 0.1 * pulse)), lineWidth: 1)
        }
        context.stroke(oval, with: .color(Color(red: 0.7, green: 0.9, blue: 1).opacity(0.45 + 0.2 * pulse)), lineWidth: 1.5)
    }

    /// 이음매 쪽 끝의 둥근 유리 테두리. 바깥 끝은 어항 자체 윤곽이 있어 건드리지 않는다.
    private static func drawRim(in context: inout GraphicsContext, size: CGSize, edge: Edge) {
        let w = size.width, h = size.height
        let r = min(28, min(w, h) / 2) - 1
        var path = Path()
        switch edge {
        case .bottom:
            path.move(to: CGPoint(x: 1, y: h - r - 1))
            path.addArc(tangent1End: CGPoint(x: 1, y: h - 1), tangent2End: CGPoint(x: 1 + r, y: h - 1), radius: r)
            path.addLine(to: CGPoint(x: w - 1 - r, y: h - 1))
            path.addArc(tangent1End: CGPoint(x: w - 1, y: h - 1), tangent2End: CGPoint(x: w - 1, y: h - 1 - r), radius: r)
        case .top:
            path.move(to: CGPoint(x: 1, y: r + 1))
            path.addArc(tangent1End: CGPoint(x: 1, y: 1), tangent2End: CGPoint(x: 1 + r, y: 1), radius: r)
            path.addLine(to: CGPoint(x: w - 1 - r, y: 1))
            path.addArc(tangent1End: CGPoint(x: w - 1, y: 1), tangent2End: CGPoint(x: w - 1, y: 1 + r), radius: r)
        case .trailing:
            path.move(to: CGPoint(x: w - r - 1, y: 1))
            path.addArc(tangent1End: CGPoint(x: w - 1, y: 1), tangent2End: CGPoint(x: w - 1, y: 1 + r), radius: r)
            path.addLine(to: CGPoint(x: w - 1, y: h - 1 - r))
            path.addArc(tangent1End: CGPoint(x: w - 1, y: h - 1), tangent2End: CGPoint(x: w - 1 - r, y: h - 1), radius: r)
        case .leading:
            path.move(to: CGPoint(x: r + 1, y: 1))
            path.addArc(tangent1End: CGPoint(x: 1, y: 1), tangent2End: CGPoint(x: 1, y: 1 + r), radius: r)
            path.addLine(to: CGPoint(x: 1, y: h - 1 - r))
            path.addArc(tangent1End: CGPoint(x: 1, y: h - 1), tangent2End: CGPoint(x: 1 + r, y: h - 1), radius: r)
        }
        context.stroke(path, with: .color(.white.opacity(0.45)), lineWidth: 2)
    }
}
