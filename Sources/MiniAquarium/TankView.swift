import SwiftUI

struct TankView: View {
    @ObservedObject var model: AquariumModel
    /// 팝오버처럼 공간이 제한된 곳에서 배율 상한을 둔다.
    var maxScale: CGFloat = .infinity
    /// 이어 붙인 큰 어항 중 이 창이 보여줄 부분(논리 좌표). nil이면 전체.
    var viewport: CGRect?
    /// 이 창에서 Dock 건너편 어항과 이어지는 쪽 가장자리. 그곳에 포털을 그린다.
    var portal: Edge?

    private var scale: CGFloat { min(model.scale, maxScale) }

    /// 이음매 쪽 두 모서리를 둥글게 깎는다. (바깥 끝은 어항 자체의 둥근 윤곽이 있다)
    private var seamShape: UnevenRoundedRectangle {
        let radius: CGFloat = 28
        func radii(_ top: Bool, _ bottom: Bool, _ leading: Bool, _ trailing: Bool) -> RectangleCornerRadii {
            RectangleCornerRadii(
                topLeading: top && leading ? radius : 0, bottomLeading: bottom && leading ? radius : 0,
                bottomTrailing: bottom && trailing ? radius : 0, topTrailing: top && trailing ? radius : 0)
        }
        switch portal {
        case .top: return UnevenRoundedRectangle(cornerRadii: radii(true, false, true, true))
        case .bottom: return UnevenRoundedRectangle(cornerRadii: radii(false, true, true, true))
        case .leading: return UnevenRoundedRectangle(cornerRadii: radii(true, true, true, false))
        case .trailing: return UnevenRoundedRectangle(cornerRadii: radii(true, true, false, true))
        case nil: return UnevenRoundedRectangle(cornerRadii: radii(false, false, false, false))
        }
    }

    var body: some View {
        let visible = viewport ?? CGRect(origin: .zero, size: model.logicalSize)
        let size = CGSize(width: (visible.width * scale).rounded(), height: (visible.height * scale).rounded())
        Canvas { context, _ in
            context.translateBy(x: -visible.minX * scale, y: -visible.minY * scale)
            TankRenderer.draw(model, in: &context, scale: scale, now: Date())
        }
        .overlay {
            if let portal {
                Canvas { context, canvasSize in
                    PortalOverlay.draw(in: &context, size: canvasSize, edge: portal, time: Date().timeIntervalSinceReferenceDate)
                }
                .allowsHitTesting(false)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(seamShape)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in model.dragChanged() }
                .onEnded { value in
                    model.dragEnded(at: CGPoint(x: value.location.x / scale + visible.minX, y: value.location.y / scale + visible.minY))
                }
        )
    }
}
