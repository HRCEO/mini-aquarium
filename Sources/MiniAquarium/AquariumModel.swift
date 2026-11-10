import AppKit
import Combine
import MiniAquariumCore

/// 어항 상태의 단일 출처. 30fps 틱으로 시뮬레이션을 진행하고 뷰에 변경을 알린다.
final class AquariumModel: ObservableObject {
    private static let visibleInterval = 1.0 / 30
    private static let hiddenInterval = 1.0
    private static let bannerDuration = 10.0
    private static let maxTickDelta = 0.1

    @Published private(set) var frame = 0
    @Published private(set) var timer: TimerState?
    @Published private(set) var bannerUntil: Date?
    @Published private(set) var settings: AquariumSettings { didSet { L10n.current = settings.language } }
    /// Dock 옆에 맞춰 넣을 때의 창 크기(pt). nil이면 설정의 비율/크기를 따른다.
    @Published private(set) var dockedSize: CGSize?

    let sim: Simulation
    weak var window: NSWindow?

    private let eventHandlers: [AquariumEventHandler]
    private var ticker: Timer?
    private var lastTick = Date()
    private var dragStartMouse: NSPoint?
    private var dragStartOrigin: NSPoint = .zero
    private var didDrag = false

    init(settings: AquariumSettings = SettingsStore.load(), eventHandlers: [AquariumEventHandler] = [SoundAlert()]) {
        self.settings = settings
        self.eventHandlers = eventHandlers
        L10n.current = settings.language
        let rect = settings.shape.rect(in: settings.layout.logicalSize)
        sim = Simulation(tankRect: rect, shape: settings.shape)
        sim.bodyScale = settings.objectSize.fishScale
        sim.setFish(settings.fish)
        sim.attractions = makeAttractions(for: settings)
        startTicker(interval: Self.visibleInterval)
    }

    /// Dock에 들어가 있으면 Dock 모양(둥근 알약)으로 꽉 채운다.
    var shape: TankShape { isDocked ? .rounded : settings.shape }
    var tankInset: CGFloat { isDocked ? 3 : 10 }
    var tankRect: CGRect { shape.rect(in: logicalSize, inset: tankInset) }
    var effectiveLayout: TankLayout {
        guard let docked = dockedSize else { return settings.layout }
        return docked.width > docked.height ? .wide : .slim
    }
    /// 그림과 시뮬레이션이 쓰는 논리 좌표 크기. 실제 창 크기는 `scale`만큼 곱해진다.
    var logicalSize: CGSize { dockedSize ?? settings.layout.logicalSize }
    var scale: CGFloat { dockedSize == nil ? settings.size.scale : 1 }
    var windowSize: CGSize { dockedSize ?? settings.size.windowSize(base: logicalSize) }
    var isDocked: Bool { dockedSize != nil }
    /// 소품을 그릴 때 곱하는 최종 배율 (기본 배율 × 설정).
    var decorScale: CGFloat { Decor.displayScale * settings.objectSize.decorScale }

    /// Dock에 맞춘 크기를 바꾼다. 같은 값이면 아무것도 하지 않는다.
    func setDockedSize(_ size: CGSize?) {
        guard size != dockedSize else { return }
        dockedSize = size
        refreshGeometry()
    }

    /// 이어 붙인 어항의 이음매 위치. 없으면 nil.
    func setSeam(_ position: CGFloat?, vertical: Bool) {
        sim.seam = position.map { (position: $0, vertical: vertical) }
    }

    private func refreshGeometry() {
        sim.configure(tankRect: tankRect, shape: shape)
        sim.attractions = makeAttractions(for: settings)
    }

    // MARK: - Settings

    func update(_ transform: (AquariumSettings) -> AquariumSettings) {
        let next = transform(settings)
        guard next != settings else { return }
        settings = next
        sim.bodyScale = next.objectSize.fishScale
        sim.configure(tankRect: (isDocked ? TankShape.rounded : next.shape).rect(in: logicalSize, inset: tankInset), shape: isDocked ? .rounded : next.shape)
        sim.setFish(next.fish)
        sim.attractions = makeAttractions(for: next)
        SettingsStore.save(next)
    }

    func zone() -> NibbleZone {
        NibbleZone.make(shape: shape, layout: effectiveLayout, in: tankRect)
    }

    /// 물고기가 구경하러 갈 소품 위치. 동굴/성은 안쪽, 나머지는 소품 중간 높이.
    private func makeAttractions(for settings: AquariumSettings) -> [Attraction] {
        let rect = shape.rect(in: logicalSize, inset: tankInset)
        return settings.decors.map { decor in
            let factor: CGFloat
            switch decor {
            case .cave, .castle: factor = 0.25
            case .bubbler: factor = 0.9
            default: factor = 0.45
            }
            let y = rect.maxY - 9 - decor.height * decorScale * factor
            return Attraction(decor: decor, pos: CGPoint(x: decor.x(in: rect, shape: shape), y: y))
        }
    }

    // MARK: - Timer

    func startTimer(minutes: Double) {
        startTimer(TimerState(start: Date(), duration: minutes * 60))
    }

    func startTimer(untilMinuteOfDay minute: Int) {
        startTimer(TimerState.until(minuteOfDay: minute, from: Date()))
    }

    func startTimer(_ state: TimerState) {
        sim.resetBites()
        timer = state
        bannerUntil = nil
    }

    func cancelTimer() {
        timer = nil
        sim.nibbleZone = nil
    }

    // MARK: - Feeding

    func feed(at point: CGPoint) { sim.dropFood(at: point, kind: settings.food) }

    func feedRandom() {
        let rect = tankRect
        feed(at: CGPoint(x: .random(in: rect.minX...rect.maxX), y: rect.minY + 24))
    }

    // MARK: - Visibility / ticking

    func setVisible(_ isVisible: Bool) {
        startTicker(interval: isVisible ? Self.visibleInterval : Self.hiddenInterval)
    }

    private func startTicker(interval: TimeInterval) {
        ticker?.invalidate()
        lastTick = Date()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func tick() {
        let now = Date()
        let delta = min(now.timeIntervalSince(lastTick), Self.maxTickDelta)
        lastTick = now
        advance(by: delta, now: now)
    }

    /// 시뮬레이션 한 프레임. 스냅샷 렌더링처럼 실시간 틱 없이 결정적으로 진행할 때도 쓴다.
    func advance(by delta: TimeInterval, now: Date = Date()) {
        if let active = timer {
            if active.isFinished(at: now) {
                finishTimer(at: now)
            } else {
                sim.nibbleZone = settings.showTimerFood ? zone() : nil
                let cells = Double(BitePattern.defaultCellCount)
                sim.nibbleTarget = (1 - active.ratio(at: now)) * cells
                sim.nibbleRate = cells / max(active.duration, 1)
            }
        }
        if let until = bannerUntil, now >= until { bannerUntil = nil }
        sim.excitement = bannerUntil == nil ? 0 : 1
        sim.step(delta)
        frame &+= 1
    }

    /// 스냅샷에서 종료 연출을 미리 보기 위한 진입점 (소리 없음).
    func finishTimerForPreview(at now: Date) {
        bannerUntil = now.addingTimeInterval(Self.bannerDuration)
    }

    private func finishTimer(at now: Date) {
        timer = nil
        sim.nibbleZone = nil
        bannerUntil = now.addingTimeInterval(Self.bannerDuration)
        emit(.timerFinished)
    }

    private func emit(_ event: AquariumEvent) {
        eventHandlers.forEach { $0.handle(event) }
    }

    // MARK: - Window drag vs. tap (클릭=먹이, 드래그=창 이동)

    func dragChanged() {
        guard let window, !isDocked else { return }
        let mouse = NSEvent.mouseLocation
        if dragStartMouse == nil {
            dragStartMouse = mouse
            dragStartOrigin = window.frame.origin
            didDrag = false
        }
        guard let start = dragStartMouse else { return }
        let dx = mouse.x - start.x, dy = mouse.y - start.y
        if hypot(dx, dy) > 4 { didDrag = true }
        if didDrag {
            window.setFrameOrigin(NSPoint(x: dragStartOrigin.x + dx, y: dragStartOrigin.y + dy))
        }
    }

    func dragEnded(at location: CGPoint) {
        defer { dragStartMouse = nil; didDrag = false }
        if didDrag, let origin = window?.frame.origin {
            update { $0.with(origin: origin) }
        } else {
            feed(at: location)
        }
    }
}
