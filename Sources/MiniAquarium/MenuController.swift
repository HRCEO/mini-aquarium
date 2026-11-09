import AppKit
import MiniAquariumCore

private final class ActionBox {
    let run: () -> Void
    init(_ run: @escaping () -> Void) { self.run = run }
}

/// 메뉴바 아이콘과 어항 우클릭이 공유하는 메뉴. 열 때마다 현재 상태로 다시 만든다.
final class MenuController: NSObject, NSMenuDelegate {
    private static let timerPresets: [Double] = [5, 10, 25, 50, 90]

    private let model: AquariumModel
    private let toggleVisibility: () -> Void
    private let isPanelVisible: () -> Bool
    private let showPanel: () -> Void

    init(
        model: AquariumModel, isPanelVisible: @escaping () -> Bool,
        toggleVisibility: @escaping () -> Void, showPanel: @escaping () -> Void
    ) {
        self.model = model
        self.showPanel = showPanel
        self.isPanelVisible = isPanelVisible
        self.toggleVisibility = toggleVisibility
    }

    func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        return menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        populate(menu)
    }

    // MARK: - Items

    private func populate(_ menu: NSMenu) {
        menu.addItem(item("먹이 주기", model.feedRandom))
        menu.addItem(.separator())
        addTimerItems(to: menu)
        menu.addItem(.separator())
        menu.addItem(submenu("물고기", fishItems()))
        menu.addItem(submenu("인테리어", decorItems()))
        menu.addItem(submenu("물고기·소품 크기", objectSizeItems()))
        menu.addItem(submenu("먹이 종류", foodItems()))
        menu.addItem(item("Dock에 고정", state: model.settings.dockFit, { [model] in
            model.update { $0.with(dockFit: !$0.dockFit) }
        }))
        menu.addItem(submenu("Dock 기준 위치", edgeItems()))
        menu.addItem(submenu("플로팅 크기", sizeItems()))
        menu.addItem(submenu("플로팅 비율", layoutItems()))
        menu.addItem(submenu("표시 방식", modeItems()))
        menu.addItem(.separator())
        menu.addItem(item("설정 열기…", showPanel))
        if model.settings.displayMode == .floating {
            menu.addItem(item(isPanelVisible() ? "어항 숨기기" : "어항 보이기", toggleVisibility))
        }
        menu.addItem(item("종료", { NSApp.terminate(nil) }))
    }

    private func addTimerItems(to menu: NSMenu) {
        if let timer = model.timer {
            let left = TimerState.format(timer.remaining(at: Date()))
            menu.addItem(item("타이머 취소 (\(left) 남음)", model.cancelTimer))
            return
        }
        var presets = Self.timerPresets.map { minutes in
            item("\(Int(minutes))분", { [model] in model.startTimer(minutes: minutes) })
        }
        presets.append(.separator())
        presets.append(item("직접 입력…", promptCustomMinutes))
        menu.addItem(submenu("타이머 시작", presets))
    }

    private func fishItems() -> [NSMenuItem] {
        let counts = Dictionary(grouping: model.settings.fish, by: { $0 }).mapValues(\.count)
        var items = Species.allCases.map { species in
            let count = counts[species, default: 0]
            let suffix = count > 0 ? "  (\(count))" : ""
            return item("\(species.title) 추가\(suffix)", { [model] in
                model.update { $0.adding(species) }
            })
        }
        items.append(.separator())
        items.append(item("마지막 물고기 빼기", { [model] in model.update { $0.removingLastFish() } }))
        return items
    }

    private func shapeItems() -> [NSMenuItem] {
        TankShape.allCases.map { shape in
            item(shape.title, state: model.settings.shape == shape, { [model] in
                model.update { $0.with(shape: shape) }
            })
        }
    }

    private func decorItems() -> [NSMenuItem] {
        Decor.allCases.map { decor in
            item(decor.title, state: model.settings.decors.contains(decor), { [model] in
                model.update { $0.toggling(decor) }
            })
        }
    }

    private func foodItems() -> [NSMenuItem] {
        FoodKind.allCases.map { food in
            item(food.title, state: model.settings.food == food, { [model] in model.update { $0.with(food: food) } })
        }
    }

    private func edgeItems() -> [NSMenuItem] {
        DockEdge.allCases.map { edge in
            item(edge.title(vertical: MainActor.assumeIsolated { DockPlacement.current()?.isVertical ?? true }), state: model.settings.dockEdge == edge, { [model] in model.update { $0.with(dockEdge: edge) } })
        }
    }

    private func objectSizeItems() -> [NSMenuItem] {
        ObjectSize.allCases.map { size in
            item(size.title, state: model.settings.objectSize == size, { [model] in model.update { $0.with(objectSize: size) } })
        }
    }

    private func sizeItems() -> [NSMenuItem] {
        TankSize.allCases.map { size in
            item(size.title, state: model.settings.size == size, { [model] in model.update { $0.with(size: size) } })
        }
    }

    private func layoutItems() -> [NSMenuItem] {
        TankLayout.allCases.map { layout in
            item(layout.title, state: model.settings.layout == layout, { [model] in model.update { $0.with(layout: layout) } })
        }
    }

    private func modeItems() -> [NSMenuItem] {
        DisplayMode.allCases.map { mode in
            item(mode.title, state: model.settings.displayMode == mode, { [model] in model.update { $0.with(displayMode: mode) } })
        }
    }

    // MARK: - Helpers

    private func item(_ title: String, state: Bool = false, _ action: @escaping () -> Void) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: #selector(fire(_:)), keyEquivalent: "")
        menuItem.target = self
        menuItem.representedObject = ActionBox(action)
        menuItem.state = state ? .on : .off
        return menuItem
    }

    private func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let child = NSMenu(title: title)
        items.forEach(child.addItem)
        parent.submenu = child
        return parent
    }

    @objc private func fire(_ sender: NSMenuItem) {
        (sender.representedObject as? ActionBox)?.run()
    }

    private func promptCustomMinutes() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "타이머 시간 (분)"
        alert.informativeText = "예: 15 또는 7.5"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        field.stringValue = "15"
        alert.accessoryView = field
        alert.addButton(withTitle: "시작")
        alert.addButton(withTitle: "취소")
        guard alert.runModal() == .alertFirstButtonReturn,
              let minutes = Double(field.stringValue.trimmingCharacters(in: .whitespaces)),
              minutes > 0, minutes <= 24 * 60
        else { return }
        model.startTimer(minutes: minutes)
    }
}
