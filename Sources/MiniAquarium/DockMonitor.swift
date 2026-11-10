import AppKit

/// Dock 모양이 바뀌었을 수 있는 모든 계기를 모아 하나의 콜백(`onChange`)으로 알려준다.
///
/// 계기는 두 가지다.
/// - 주기 폴링: 앱을 실행·종료하면 Dock 아이콘이 늘고 줄지만 이를 알려주는 공개 알림이 없다.
/// - 화면 구성 변경: 해상도·모니터 연결·Dock 위치/크기/자동 숨김 변경.
///
/// `onChange`는 "바뀌었을 수 있다"는 뜻일 뿐이라 자주 불린다. 받는 쪽은 값이 같으면 아무것도 하지 않게 만들어야 한다.
/// 새로운 계기(예: 앱 활성화, Space 전환)가 필요하면 `start()`에 옵저버를 하나 더하면 된다.
@MainActor
final class DockMonitor {
    static let refreshInterval: TimeInterval = 0.5

    private let onChange: () -> Void
    private var timer: Timer?
    private var screenObserver: NSObjectProtocol?

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.onChange() }
        }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.onChange() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        screenObserver = nil
    }
}
