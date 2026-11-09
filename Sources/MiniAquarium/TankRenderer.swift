import MiniAquariumCore
import SwiftUI

extension TankShape {
    func path(in rect: CGRect) -> Path {
        isEllipse
            ? Path(ellipseIn: rect)
            : Path(roundedRect: rect, cornerRadius: cornerRadius, style: .continuous)
    }
}

/// Canvas에 어항 전체를 그린다. 모든 그리기는 읽기 전용(모델 상태를 바꾸지 않는다).
enum TankRenderer {
    private static let waterTop = Color(red: 0.36, green: 0.72, blue: 0.90)
    private static let waterBottom = Color(red: 0.08, green: 0.38, blue: 0.66)
    private static let sand = Color(red: 0.93, green: 0.84, blue: 0.62)
    private static let bread = Color(red: 0.98, green: 0.78, blue: 0.40)

    static func draw(_ model: AquariumModel, in context: inout GraphicsContext, scale: CGFloat, now: Date) {
        context.scaleBy(x: scale, y: scale)
        let shape = model.shape
        let rect = shape.rect(in: model.logicalSize, inset: model.tankInset)
        let outline = shape.path(in: rect)
        let sim = model.sim
        let t = sim.time
        let decors = Decor.drawOrder(model.settings.decors)

        context.drawLayer { layer in
            layer.clip(to: outline)
            drawWater(&layer, rect: rect)
            drawPlankton(&layer, rect: rect, time: t)
            drawSand(&layer, rect: rect)
            drawDecors(&layer, decors.filter { $0.layer < 2 }, rect: rect, shape: shape, time: t, scale: model.decorScale)
            drawBubbles(&layer, rect: rect, time: t)
            let zone = model.timer != nil && model.settings.showTimerFood ? model.zone() : nil
            // 가로 띠는 소품에 가려지지 않게 맨 위에 그린다. (세로 띠는 소품과 겹치지 않아 물고기 뒤에 둔다)
            let stripOnTop = zone.map { !$0.isVertical } ?? false
            if let zone, !stripOnTop { drawStrip(&layer, zone: zone, bites: sim.bites) }
            drawFish(&layer, sim: sim)
            drawDecors(&layer, decors.filter { $0.layer >= 2 }, rect: rect, shape: shape, time: t, scale: model.decorScale)
            if let zone, stripOnTop { drawStrip(&layer, zone: zone, bites: sim.bites, backdrop: true) }
            drawFoods(&layer, sim: sim)
            drawCrumbs(&layer, sim: sim)
        }

        drawGlass(&context, outline: outline, rect: rect)
        drawAlert(&context, model: model, outline: outline, rect: rect, now: now)
        drawHeader(&context, model: model, rect: rect, now: now)
    }

    private static func drawDecors(_ layer: inout GraphicsContext, _ decors: [Decor], rect: CGRect, shape: TankShape, time: Double, scale: CGFloat) {
        for decor in decors {
            layer.drawLayer { item in
                item.translateBy(x: decor.x(in: rect, shape: shape), y: rect.maxY - 9)
                item.scaleBy(x: scale, y: scale)
                DecorArt.draw(decor, in: &item, t: time + Double(decor.slot) * 10)
            }
        }
    }

    private static func drawPlankton(_ layer: inout GraphicsContext, rect: CGRect, time: Double) {
        for index in 0..<16 {
            let seed = Double(index)
            let x = rect.minX + rect.width * Art.noise(seed * 3.1) + sin(time * 0.4 + seed) * 6
            let y = rect.minY + (rect.height - 30) * ((Art.noise(seed * 7.7) + time * 0.01 * (0.5 + Art.noise(seed))).truncatingRemainder(dividingBy: 1))
            layer.fill(Art.circle(Art.p(x, y), 0.7 + Art.noise(seed + 2) * 0.8), with: .color(.white.opacity(0.18 + 0.12 * Art.noise(seed + 8))))
        }
    }

    // MARK: - Layers

    private static func drawWater(_ layer: inout GraphicsContext, rect: CGRect) {
        layer.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(colors: [waterTop, waterBottom]),
                startPoint: CGPoint(x: rect.midX, y: rect.minY),
                endPoint: CGPoint(x: rect.midX, y: rect.maxY)
            )
        )
        var ray = Path()
        ray.move(to: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.minY))
        ray.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.minY))
        ray.addLine(to: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.maxY))
        ray.addLine(to: CGPoint(x: rect.minX + rect.width * 0.02, y: rect.maxY))
        layer.fill(ray, with: .color(.white.opacity(0.07)))
    }

    private static func drawSand(_ layer: inout GraphicsContext, rect: CGRect) {
        let top = rect.maxY - 22
        var dune = Path()
        dune.move(to: Art.p(rect.minX, rect.maxY))
        dune.addLine(to: Art.p(rect.minX, top + 4))
        dune.addCurve(to: Art.p(rect.maxX, top + 2), control1: Art.p(rect.width * 0.3, top - 4), control2: Art.p(rect.width * 0.7, top + 8))
        dune.addLine(to: Art.p(rect.maxX, rect.maxY))
        dune.closeSubpath()
        layer.fill(dune, with: Art.vertical(Art.c(0.95, 0.87, 0.66), Art.c(0.78, 0.66, 0.46), top, rect.maxY))
        for index in 0..<46 {
            let seed = Double(index)
            let x = rect.minX + rect.width * Art.noise(seed * 1.7)
            let y = top + 6 + (rect.height - (rect.height - 22) - 8) * Art.noise(seed * 5.3)
            let tone = 0.5 + 0.4 * Art.noise(seed + 11)
            layer.fill(Art.oval(Art.p(x, y), 1.1 + Art.noise(seed + 3) * 1.4, 0.8 + Art.noise(seed + 4)), with: .color(Art.c(tone, tone * 0.88, tone * 0.66, 0.75)))
        }
    }

    private static func drawBubbles(_ layer: inout GraphicsContext, rect: CGRect, time: Double) {
        for index in 0..<6 {
            let seed = Double(index)
            let progress = (time * 0.12 + seed / 6).truncatingRemainder(dividingBy: 1)
            let baseX = rect.minX + rect.width * (0.15 + 0.7 * fraction(sin(seed * 12.9898) * 43758.5453))
            let x = baseX + CGFloat(sin(time * 2 + seed)) * 4
            let y = rect.maxY - 22 - CGFloat(progress) * (rect.height - 40)
            let radius = CGFloat(2 + index % 3)
            let bubble = Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
            layer.stroke(bubble, with: .color(.white.opacity(0.55)), lineWidth: 1)
        }
    }

    private static func fraction(_ value: Double) -> Double { value - value.rounded(.down) }

    private static func drawStrip(_ layer: inout GraphicsContext, zone: NibbleZone, bites: BiteField, backdrop: Bool = false) {
        let bar = zone.bar
        layer.drawLayer { strip in
            if backdrop {
                // 소품 위에서도 눈에 띄도록 어두운 테두리를 깐다. 필터 대신 같은 레이어에 그려서 갉아낼 때 함께 지워진다.
                strip.fill(Path(roundedRect: bar.insetBy(dx: -2, dy: -2), cornerRadius: 7), with: .color(Art.c(0.05, 0.2, 0.35).opacity(0.55)))
            }
            strip.fill(Path(roundedRect: bar, cornerRadius: 5), with: .color(Art.c(0.98, 0.78, 0.40)))
            let shine = zone.isVertical
                ? CGRect(x: bar.minX, y: bar.minY, width: 4, height: bar.height)
                : CGRect(x: bar.minX, y: bar.minY, width: bar.width, height: 4)
            strip.fill(Path(roundedRect: shine, cornerRadius: 2), with: .color(.white.opacity(0.35)))
            // 갉아먹은 자리: 칸마다 먹힌 정도만큼 파내고, 구멍 가장자리는 둥글게 물어뜯은 모양을 낸다.
            strip.blendMode = .clear
            let thickness = zone.isVertical ? bar.width : bar.height
            for cell in 0..<zone.cellCount {
                let eaten = bites.eaten[cell]
                guard eaten > 0 else { continue }
                let rect = zone.cellRect(cell)
                if eaten >= 1 {
                    // 이웃 칸과 살짝 겹쳐 경계에 실선이 남지 않게 한다
                    strip.fill(Path(rect.insetBy(dx: zone.isVertical ? -1 : -0.6, dy: zone.isVertical ? -0.6 : -1)), with: .color(.black))
                    continue
                }
                // 물고기가 있는 옆면에서 안쪽으로 둥글게 파고들고, 다 먹히면 칸이 통째로 사라진다.
                let depth = thickness * eaten * 1.1
                let width = rect.width * (zone.isVertical ? 0 : 1) + rect.height * (zone.isVertical ? 1 : 0)
                let span = width * 1.2 + thickness * 0.35
                let edge = bites.sides[cell] == 0 ? 0.0 : 1.0
                let center: CGPoint
                let size: CGSize
                if zone.isVertical {
                    center = Art.p(edge == 0 ? bar.minX : bar.maxX, rect.midY)
                    size = CGSize(width: depth * 2, height: span)
                } else {
                    center = Art.p(rect.midX, edge == 0 ? bar.minY : bar.maxY)
                    size = CGSize(width: span, height: depth * 2)
                }
                strip.fill(Path(ellipseIn: CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)), with: .color(.black))
            }
            // 구멍 가장자리를 들쭉날쭉하게
            for cell in 1..<zone.cellCount {
                let before = bites.eaten[cell - 1] >= 1, after = bites.eaten[cell] >= 1
                guard before != after else { continue }
                let rect = zone.cellRect(cell)
                let jitter = CGFloat(Art.noise(Double(cell) * 3.1) - 0.5) * thickness * 0.6
                let edge = zone.isVertical ? Art.p(bar.midX + jitter, rect.minY) : Art.p(rect.minX, bar.midY + jitter)
                strip.fill(Art.circle(edge, thickness * (0.22 + 0.16 * CGFloat(Art.noise(Double(cell) * 7.7)))), with: .color(.black))
            }
        }
    }

    private static func drawFoods(_ layer: inout GraphicsContext, sim: Simulation) {
        for food in sim.foods { FoodArt.draw(food, in: &layer) }
    }

    private static func drawCrumbs(_ layer: inout GraphicsContext, sim: Simulation) {
        for crumb in sim.crumbs {
            let r: CGFloat = 1.6
            let dot = Path(ellipseIn: CGRect(x: crumb.pos.x - r, y: crumb.pos.y - r, width: r * 2, height: r * 2))
            layer.fill(dot, with: .color(bread.opacity(max(0, crumb.life))))
        }
    }

    private static func drawFish(_ layer: inout GraphicsContext, sim: Simulation) {
        for fish in sim.fish {
            layer.drawLayer { sprite in
                sprite.translateBy(x: fish.pos.x, y: fish.pos.y)
                if fish.facingLeft { sprite.scaleBy(x: -1, y: 1) }
                if !fish.species.isUpright {
                    let swim = Double(atan2(fish.vel.dy, max(abs(fish.vel.dx), 8))).clamped(to: -0.5...0.5) * 0.6
                    sprite.rotate(by: .radians(swim + fish.nibbleTilt))
                }
                if fish.isInside { sprite.opacity = 0.5 }
                let bob = fish.species.isUpright ? sin(sim.time * 1.6 + fish.phase) * 2 : 0
                sprite.translateBy(x: 0, y: bob)
                let pulse = 1 + fish.eatPulse * 0.4
                let side = fish.species.size * sim.bodyScale * pulse
                sprite.scaleBy(x: side, y: side)
                FishArt.draw(fish.species, in: &sprite, t: sim.time + fish.phase, eating: fish.eatPulse)
            }
        }
    }

    private static func drawGlass(_ context: inout GraphicsContext, outline: Path, rect: CGRect) {
        context.stroke(outline, with: .color(.white.opacity(0.55)), lineWidth: 3)
        context.stroke(outline.strokedPath(StrokeStyle(lineWidth: 1)), with: .color(.black.opacity(0.15)), lineWidth: 0.5)
    }

    // MARK: - Timer finished

    /// 타이머가 끝나면 한동안 황금빛 테두리가 맥박치고 바닥에서 방울이 솟는다.
    private static func drawAlert(_ context: inout GraphicsContext, model: AquariumModel, outline: Path, rect: CGRect, now: Date) {
        guard let until = model.bannerUntil else { return }
        let t = now.timeIntervalSinceReferenceDate
        let fade = min(1, until.timeIntervalSince(now) / 1.5)
        let pulse = 0.5 + 0.5 * sin(t * 7)
        context.stroke(outline, with: .color(Art.c(1, 0.82, 0.25, (0.45 + 0.4 * pulse) * fade)), lineWidth: 4 + 3 * pulse)
        context.drawLayer { layer in
            layer.clip(to: outline)
            for i in 0..<18 {
                let life = (t * 0.55 + Double(i) / 18).truncatingRemainder(dividingBy: 1)
                let x = rect.minX + rect.width * (0.08 + 0.84 * Art.noise(Double(i) * 3.1))
                    + CGFloat(sin(t * 3 + Double(i)) * 6)
                let y = rect.maxY - life * rect.height
                let r = 2.5 + 4 * Art.noise(Double(i) + 11)
                let bubble = Art.circle(CGPoint(x: x, y: y), r)
                layer.fill(bubble, with: .color(.white.opacity(0.22 * fade)))
                layer.stroke(bubble, with: .color(.white.opacity(0.85 * fade)), lineWidth: 1)
            }
        }
    }

    // MARK: - Header text

    private static func timeFontSize(_ text: String, width: CGFloat) -> CGFloat {
        min(26, max(9, width * 0.86 / (CGFloat(text.count) * 0.62)))
    }

    private static func drawHeader(_ context: inout GraphicsContext, model: AquariumModel, rect: CGRect, now: Date) {
        let y = model.shape.headerY(in: rect)
        let center = CGPoint(x: rect.midX, y: y)
        let timeText: String
        let caption: String
        if let timer = model.timer {
            guard model.settings.showRemaining else { return }   // 글씨만 숨긴다 (바·물고기는 그대로)
            caption = tr("남은 시간", "Time left")
            timeText = TimerState.format(timer.remaining(at: now))
        } else if model.bannerUntil != nil {
            caption = tr("⏰ 끝났어요!", "⏰ Time's up!")
            timeText = "00:00"
        } else {
            return   // 평소에는 시계를 그리지 않는다
        }
        if rect.height < NibbleZone.compactHeight {   // 가로로 납작한 어항: 오른쪽 끝에 글씨, 그 앞으로 먹이 띠
            context.drawLayer { text in
                text.addFilter(.shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1))
                text.draw(
                    Text("\(caption)  \(timeText)").font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit()).foregroundColor(.white),
                    at: CGPoint(x: rect.maxX - NibbleZone.compactEdgePadding, y: rect.midY), anchor: .trailing
                )
            }
            return
        }
        let narrow = rect.width < 90
        context.drawLayer { text in
            text.addFilter(.shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1))
            text.draw(
                Text(caption).font(.system(size: narrow ? 9 : 11, weight: .semibold)).foregroundColor(.white.opacity(0.9)),
                at: CGPoint(x: center.x, y: center.y - 8), anchor: .center
            )
            text.draw(
                Text(timeText).font(.system(size: timeFontSize(timeText, width: rect.width), weight: .bold, design: .rounded).monospacedDigit()).foregroundColor(.white),
                at: CGPoint(x: center.x, y: center.y + 12), anchor: .center
            )
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self { min(max(self, range.lowerBound), range.upperBound) }
}
