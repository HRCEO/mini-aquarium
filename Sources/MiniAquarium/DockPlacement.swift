import AppKit
import MiniAquariumCore

/// 현재 Dock 위치/크기를 읽어 그 옆 빈 자리를 알려준다.
@MainActor
enum DockPlacement {
    private static let defaultTile: CGFloat = 64
    private static let fallbackItemCount = 12

    static func current(gap: CGFloat = DockFit.margin) -> DockRegion? {
        let (items, tile) = dockMetrics()
        let measured = measuredPill()
        for screen in NSScreen.screens {
            if let region = DockFit.region(screen: screen.frame, visible: screen.visibleFrame, dockItems: items, tile: tile, measuredPill: measured, gap: gap) {
                return region
            }
        }
        return nil
    }

    /// Dock 설정과 실행 중인 앱으로 아이콘 개수를 어림한다 (실제 길이는 손쉬운 사용 권한이 있어야 정확).
    private static func dockMetrics() -> (items: Int, tile: CGFloat) {
        let id = "com.apple.dock" as CFString
        CFPreferencesAppSynchronize(id)
        func entries(_ key: String) -> [[String: Any]] {
            (CFPreferencesCopyAppValue(key as CFString, id) as? [[String: Any]]) ?? []
        }
        let apps = entries("persistent-apps")
        let others = entries("persistent-others")
        let showRecents = (CFPreferencesCopyAppValue("show-recents" as CFString, id) as? Bool) ?? true
        let recents = showRecents ? entries("recent-apps").count : 0
        let pinned = Set(apps.compactMap { ($0["tile-data"] as? [String: Any])?["bundle-identifier"] as? String })
        let running = Set(NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }.compactMap(\.bundleIdentifier))
            .subtracting(["com.apple.finder"])   // Finder는 +2에 이미 들어 있다
        let unpinned = running.subtracting(pinned).count
        let tile = (CFPreferencesCopyAppValue("tilesize" as CFString, id) as? Double).map { CGFloat($0) } ?? defaultTile
        let count = apps.count + others.count + unpinned + recents + 2   // +2: Finder, 휴지통 (구분선은 DockFit이 따로 더한다)
        return (count > 3 ? count : fallbackItemCount, tile > 0 ? tile : defaultTile)
    }

    /// 손쉬운 사용 권한이 있으면 Dock 아이콘 목록의 실제 길이를 읽는다. 없으면 nil (어림값 사용).
    /// 앱 번들(.app)로 실행했을 때만 묻는다. 실행 파일을 직접 돌리면 권한 목록에 별개 항목이 생기기 때문이다.
    static func requestAccessibility() {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return }
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
    }

    static var isAccessibilityGranted: Bool { AXIsProcessTrusted() }

    /// 시스템 설정의 손쉬운 사용 화면을 연다.
    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// 아이콘 목록의 실제 영역(AppKit 좌표). 권한이 없으면 nil.
    private static func measuredPill() -> CGRect? {
        guard AXIsProcessTrusted(),
              let dock = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.dock" }),
              let primary = NSScreen.screens.first
        else { return nil }
        let app = AXUIElementCreateApplication(dock.processIdentifier)
        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXChildrenAttribute as CFString, &children) == .success,
              let list = (children as? [AXUIElement])?.first,
              let origin = axPoint(list, kAXPositionAttribute), let size = axSize(list, kAXSizeAttribute)
        else { return nil }
        // AX 좌표는 왼쪽 위 원점 → AppKit 왼쪽 아래 원점
        return CGRect(x: origin.x, y: primary.frame.height - origin.y - size.height, width: size.width, height: size.height)
    }

    private static func axPoint(_ element: AXUIElement, _ attribute: String) -> CGPoint? {
        var value: CFTypeRef?
        var point = CGPoint.zero
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success, let raw = value,
              AXValueGetValue(raw as! AXValue, .cgPoint, &point) else { return nil }
        return point
    }

    private static func axSize(_ element: AXUIElement, _ attribute: String) -> CGSize? {
        var value: CFTypeRef?
        var size = CGSize.zero
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success, let raw = value,
              AXValueGetValue(raw as! AXValue, .cgSize, &size) else { return nil }
        return size
    }
}
