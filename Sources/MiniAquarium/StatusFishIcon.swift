import AppKit
import MiniAquariumCore
import SwiftUI

/// 메뉴바용 헤엄치는 물고기 프레임. FishArt의 모든 움직임은 2π 주기라 끊김 없이 반복된다.
@MainActor
enum StatusFishIcon {
    static let frameCount = 28   // 많을수록 느긋하게 헤엄친다
    private static let canvasSize = CGSize(width: 30, height: 18)

    static func frames(for species: Species) -> [NSImage] {
        (0..<frameCount).compactMap { index in
            let phase = Double(index) / Double(frameCount) * 2 * .pi
            let content = Canvas { context, size in
                let side = species.isUpright ? size.height * 0.95 : size.height * 1.25
                context.translateBy(x: size.width / 2 + CGFloat(sin(phase)) * 0.8, y: size.height / 2 + CGFloat(cos(phase * 2)) * 0.6)
                context.scaleBy(x: side, y: side)
                FishArt.draw(species, in: &context, t: phase, eating: 0)
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            let renderer = ImageRenderer(content: content)
            renderer.scale = 3
            guard let image = renderer.nsImage else { return nil }
            image.size = canvasSize
            image.isTemplate = false
            return image
        }
    }
}
