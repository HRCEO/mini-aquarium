import AppKit
import Combine
import MiniAquariumCore
import SwiftUI

/// 항상 위에 떠 있지만 포커스는 뺏지 않는 투명 패널.
private final class AquariumPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// 우클릭하면 공유 메뉴를 띄우는 호스팅 뷰.
private final class AquariumHostingView: NSHostingView<TankView> {
    var contextMenuProvider: (() -> NSMenu)?

    override func rightMouseDown(with event: NSEvent) {
        guard let menu = contextMenuProvider?() else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var model: AquariumModel!
    private var panel: AquariumPanel!
    private var mirrorPanel: AquariumPanel!   // '양쪽'일 때 긴 어항의 뒤쪽 절반을 보여준다
    private var statusItem: NSStatusItem!
    private var menuController: MenuController!
    private let popover = NSPopover()
    private var clockTimer: Timer?
    private var dockTimer: Timer?
    private var screenObserver: NSObjectProtocol?
    private var settingsObserver: AnyCancellable?
    private var appliedMode: DisplayMode?
    private var iconFrames: [NSImage] = []
    private var iconSpecies: Species?
    private var iconTick = 0
    private var dockRegion: DockRegion?
    private var wasDocked = false
    private static let dockRefreshInterval = 0.5  // 앱 실행/종료로 Dock이 늘고 줄면 어항도 따라간다

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        // 이미 실행 중이면 새로 뜬 쪽이 조용히 종료한다 (어항이 두 개 뜨는 것을 막는다).
        if Self.hasOlderInstance() {
            NSApp.terminate(nil)
            return
        }
        DockPlacement.requestAccessibility()

        model = AquariumModel()
        panel = makePanel()
        mirrorPanel = makePanel()

        menuController = MenuController(
            model: model,
            isPanelVisible: { [weak self] in self?.panel.isVisible ?? false },
            toggleVisibility: { [weak self] in self?.toggleAquarium() },
            showPanel: { [weak self] in self?.showPopover() }
        )

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let controller = NSHostingController(rootView: PopoverContent(model: model))
        controller.sizingOptions = .preferredContentSize
        popover.contentViewController = controller
        popover.behavior = .transient
        popover.delegate = self

        settingsObserver = model.$settings.receive(on: RunLoop.main).sink { [weak self] settings in
            self?.apply(settings)
        }
        apply(model.settings)
        clockTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tickStatusItem() }
        }
        dockTimer = Timer.scheduledTimer(withTimeInterval: Self.dockRefreshInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshDock() }
        }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.refreshDock() } }
    }

    /// 같은 앱(번들 ID 또는 실행 파일 이름이 같은)이 더 먼저 떠 있으면 true.
    /// 둘이 동시에 뜨면 먼저 시작한 쪽(같으면 pid가 작은 쪽)만 남는다.
    private static func hasOlderInstance() -> Bool {
        let me = NSRunningApplication.current
        let myID = Bundle.main.bundleIdentifier
        let myName = me.executableURL?.lastPathComponent
        return NSWorkspace.shared.runningApplications.contains { other in
            guard other.processIdentifier != me.processIdentifier else { return false }
            let same = myID != nil ? other.bundleIdentifier == myID : other.executableURL?.lastPathComponent == myName
            guard same else { return false }
            switch (other.launchDate, me.launchDate) {
            case let (o?, m?) where o != m: return o < m
            default: return other.processIdentifier < me.processIdentifier
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        clockTimer?.invalidate()
        dockTimer?.invalidate()
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    }

    // MARK: - Mode handling

    private func apply(_ settings: AquariumSettings) {
        refreshDock()
        let size = model.windowSize
        if !model.isDocked, panel.frame.size != size {
            var frame = panel.frame
            frame.origin.y += frame.height - size.height   // 위쪽 모서리를 고정
            frame.size = size
            panel.setFrame(frame, display: true)
        }
        if appliedMode != settings.displayMode {
            appliedMode = settings.displayMode
            switch settings.displayMode {
            case .floating:
                model.window = panel
                panel.orderFrontRegardless()
                model.setVisible(true)
            case .menuBar:
                model.window = nil
                panel.orderOut(nil)
                mirrorPanel.orderOut(nil)
                model.setVisible(popover.isShown)
            }
        }
        refreshStatusItem()
    }

    // MARK: - Dock fit & patrol

    /// Dock 옆 빈 자리를 꽉 채우도록 크기와 위치를 정한다. 자주 불러 Dock 아이콘이 늘고 줄어도 따라간다.
    /// '양쪽'이면 두 빈 자리를 Dock 너머로 이어 하나의 긴 어항처럼 보여준다.
    private func refreshDock() {
        let settings = model.settings
        guard settings.displayMode == .floating, settings.dockFit, let region = DockPlacement.current(gap: CGFloat(settings.dockGap)) else {
            dockRegion = nil
            model.setDockedSize(nil)
            model.setSeam(nil, vertical: false)
            mirrorPanel.orderOut(nil)
            setViewport(of: panel, nil, portal: nil)
            if wasDocked { wasDocked = false; restoreSavedFrame() }
            return
        }
        dockRegion = region
        wasDocked = true
        let strips = region.strips(for: settings.dockEdge)
        guard let first = strips.first else { return }
        let thickness = strips.map { region.isVertical ? $0.width : $0.height }.min() ?? 0
        func panelSize(_ strip: CGRect) -> CGSize {
            region.isVertical ? CGSize(width: thickness, height: strip.height) : CGSize(width: strip.width, height: thickness)
        }
        let sizes = strips.map(panelSize)
        // 두 띠를 하나로 이은 긴 어항: 길이는 더하고, 각 창은 그 일부분만 보여준다.
        let total = sizes.reduce(0) { $0 + (region.isVertical ? $1.height : $1.width) }
        let world = region.isVertical ? CGSize(width: thickness, height: total) : CGSize(width: total, height: thickness)
        model.setDockedSize(world)
        model.setSeam(strips.count > 1 ? (region.isVertical ? sizes[0].height : sizes[0].width) : nil, vertical: region.isVertical)
        var offset: CGFloat = 0
        var viewports: [CGRect] = []
        for size in sizes {
            viewports.append(CGRect(origin: region.isVertical ? CGPoint(x: 0, y: offset) : CGPoint(x: offset, y: 0), size: size))
            offset += region.isVertical ? size.height : size.width
        }
        place(panel, in: first, size: sizes[0], region: region)
        let joined = strips.count > 1 && panel.isVisible
        let leading: Edge = region.isVertical ? .bottom : .trailing
        let trailing: Edge = region.isVertical ? .top : .leading
        setViewport(of: panel, viewports[0], portal: joined ? leading : nil)
        if strips.count > 1, panel.isVisible {
            place(mirrorPanel, in: strips[1], size: sizes[1], region: region)
            setViewport(of: mirrorPanel, viewports[1], portal: trailing)
            mirrorPanel.orderFrontRegardless()
        } else {
            mirrorPanel.orderOut(nil)
        }
    }

    private func setViewport(of target: AquariumPanel, _ viewport: CGRect?, portal: Edge?) {
        guard let host = target.contentView as? AquariumHostingView,
              host.rootView.viewport != viewport || host.rootView.portal != portal else { return }
        host.rootView = TankView(model: model, viewport: viewport, portal: portal)
    }

    /// 띠 안에서 Dock 아이콘 줄 반대쪽(화면 가장자리) 쪽으로 붙인다.
    private func place(_ target: AquariumPanel, in strip: CGRect, size: CGSize, region: DockRegion) {
        let isBefore = strip == region.before
        let origin: NSPoint
        if region.isVertical {
            origin = NSPoint(x: strip.minX, y: isBefore ? strip.maxY - size.height : strip.minY)
        } else {
            origin = NSPoint(x: isBefore ? strip.minX : strip.maxX - size.width, y: strip.minY)
        }
        let frame = NSRect(origin: origin, size: size)
        if target.frame != frame { target.setFrame(frame, display: true) }
    }

    private func restoreSavedFrame() {
        let size = model.windowSize
        panel.setFrame(NSRect(origin: initialOrigin(size: size), size: size), display: true)
    }

    // MARK: - Status item

    private func tickStatusItem() {
        iconTick &+= 1
        refreshStatusItem()
    }

    private func refreshStatusItem() {
        guard let button = statusItem.button else { return }
        let species = model.settings.statusFish
        if iconSpecies != species || iconFrames.isEmpty {
            iconSpecies = species
            iconFrames = StatusFishIcon.frames(for: species)
        }
        if !iconFrames.isEmpty { button.image = iconFrames[iconTick % iconFrames.count] }
        let text = statusText()
        if button.title != text { button.title = text }
        button.imagePosition = text.isEmpty ? .imageOnly : .imageLeft
    }

    private func statusText() -> String {
        model.bannerUntil != nil ? " " + tr("⏰ 끝났어요!", "⏰ Time's up!") : ""
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let isRight = NSApp.currentEvent?.type == .rightMouseUp
        if isRight {
            let menu = menuController.makeMenu()
            statusItem.menu = menu
            sender.performClick(nil)
            statusItem.menu = nil
        } else if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button, !popover.isShown else { return }
        model.setVisible(true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    func popoverDidClose(_ notification: Notification) {
        model.setVisible(model.settings.displayMode == .floating && panel.isVisible)
    }

    // MARK: - Floating panel

    private func makePanel() -> AquariumPanel {
        let size = model.windowSize
        let panel = AquariumPanel(
            contentRect: NSRect(origin: initialOrigin(size: size), size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let host = AquariumHostingView(rootView: TankView(model: model))
        host.sizingOptions = []
        host.contextMenuProvider = { [weak self] in self?.menuController.makeMenu() ?? NSMenu() }
        panel.contentView = host
        return panel
    }

    private func initialOrigin(size: CGSize) -> NSPoint {
        let saved = model.settings
        if let x = saved.originX, let y = saved.originY { return NSPoint(x: x, y: y) }
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return NSPoint(x: screen.maxX - size.width - 24, y: screen.minY + 24)
    }

    private func toggleAquarium() {
        guard model.settings.displayMode == .floating else { return showPopover() }
        if panel.isVisible {
            panel.orderOut(nil)
            mirrorPanel.orderOut(nil)
            model.setVisible(false)
        } else {
            panel.orderFrontRegardless()
            model.setVisible(true)
            refreshDock()
        }
    }
}
