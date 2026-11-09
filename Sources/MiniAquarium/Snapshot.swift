import AppKit
import MiniAquariumCore
import SwiftUI

/// `MiniAquarium --snapshot out.png [--shape rounded|bowl|tall] [--timer 0.6] [--feed] [--size small|medium|large|huge] [--popover]`
/// 화면 녹화 권한 없이 어항을 PNG로 렌더링해 시각 검증에 쓴다.
@MainActor
enum Snapshot {
    static func run(arguments: [String]) -> Never {
        if let icon = value(after: "--icon", in: arguments) { writeIcon(to: icon) }
        guard let path = value(after: "--snapshot", in: arguments) else {
            FileHandle.standardError.write(Data("usage: --snapshot <out.png>\n".utf8))
            exit(2)
        }
        let shape = value(after: "--shape", in: arguments).flatMap(TankShape.init(rawValue:)) ?? .rounded
        let timerRatio = value(after: "--timer", in: arguments).flatMap(Double.init)

        let settings = AquariumSettings(
            fish: Species.allCases,
            shape: shape,
            size: value(after: "--size", in: arguments).flatMap(TankSize.init(rawValue:)) ?? .medium,
            layout: value(after: "--layout", in: arguments).flatMap(TankLayout.init(rawValue:)) ?? .standard,
            objectSize: value(after: "--objects", in: arguments).flatMap(ObjectSize.init(rawValue:)) ?? .normal,
            decors: Decor.allCases,
            showRemaining: !arguments.contains("--hide-remaining"),
            showTimerFood: !arguments.contains("--hide-food")
        )
        let model = AquariumModel(settings: settings)
        let now = Date()
        if let dock = value(after: "--dock", in: arguments)?.split(separator: "x").compactMap({ Double($0) }), dock.count == 2 {
            model.setDockedSize(CGSize(width: dock[0], height: dock[1]))
        }
        if arguments.contains("--finish") { model.finishTimerForPreview(at: now) }

        if let ratio = timerRatio {
            let total = 600.0
            model.startTimer(TimerState(start: now.addingTimeInterval(-total * (1 - ratio)), duration: total))
        }
        if arguments.contains("--feed") {
            model.feed(at: CGPoint(x: model.tankRect.midX, y: model.tankRect.minY + 60))
        }
        for _ in 0..<(30 * 6) { model.advance(by: 1.0 / 30, now: now) }

        let viewport = value(after: "--viewport", in: arguments)?.split(separator: ",").compactMap({ Double($0) })
            .chunkedRect()
        let content: AnyView = arguments.contains("--popover")
            ? AnyView(PopoverContent(model: model).background(Color(white: 0.95)))
            : AnyView(TankView(model: model, viewport: viewport, portal: portalEdge(in: arguments)).background(Color(white: 0.92)))
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
        else {
            FileHandle.standardError.write(Data("render failed\n".utf8))
            exit(1)
        }
        do {
            try png.write(to: URL(fileURLWithPath: path))
        } catch {
            FileHandle.standardError.write(Data("write failed: \(error)\n".utf8))
            exit(1)
        }
        exit(0)
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    /// 앱 아이콘(1024px): 파란 물속의 금붕어.
    private static func writeIcon(to path: String) -> Never {
        let view = ZStack {
            RoundedRectangle(cornerRadius: 230, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.36, green: 0.74, blue: 0.95), Color(red: 0.07, green: 0.34, blue: 0.62)], startPoint: .top, endPoint: .bottom))
            Canvas { context, size in
                for (x, y, r) in [(0.22, 0.28, 34.0), (0.3, 0.18, 20.0), (0.78, 0.22, 26.0), (0.84, 0.36, 14.0)] {
                    let bubble = Path(ellipseIn: CGRect(x: size.width * x - r, y: size.height * y - r, width: r * 2, height: r * 2))
                    context.fill(bubble, with: .color(.white.opacity(0.18)))
                    context.stroke(bubble, with: .color(.white.opacity(0.7)), lineWidth: 5)
                }
                context.translateBy(x: size.width * 0.6, y: size.height * 0.54)
                context.scaleBy(x: size.width * 0.58, y: size.width * 0.58)
                FishArt.draw(.goldfish, in: &context, t: 0.6, eating: 0)
            }
        }
        .frame(width: 1024, height: 1024)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]),
              (try? png.write(to: URL(fileURLWithPath: path))) != nil else { exit(1) }
        exit(0)
    }
}


private extension Array where Element == Double {
    /// "x,y,w,h" → CGRect
    func chunkedRect() -> CGRect? { count == 4 ? CGRect(x: self[0], y: self[1], width: self[2], height: self[3]) : nil }
}

private func portalEdge(in arguments: [String]) -> Edge? {
    guard let index = arguments.firstIndex(of: "--portal"), index + 1 < arguments.count else { return nil }
    switch arguments[index + 1] {
    case "top": return .top
    case "bottom": return .bottom
    case "leading": return .leading
    case "trailing": return .trailing
    default: return nil
    }
}
