import Foundation
import ServiceManagement

enum AppInfo {
    static let author = "HRCEO"
    static let email = "hrceolee@gmail.com"
    /// 후원 페이지 (Ko-fi). README, .github/FUNDING.yml과 같은 주소를 써요.
    static let supportURL = URL(string: "https://ko-fi.com/hrceo")
    static let version = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0.0"
}

/// 로그인 시 자동 실행 (앱 번들로 실행했을 때만 동작).
enum LaunchAtLogin {
    static var isAvailable: Bool { Bundle.main.bundleURL.pathExtension == "app" }

    static var isEnabled: Bool {
        isAvailable && SMAppService.mainApp.status == .enabled
    }

    static func set(_ on: Bool) throws {
        guard isAvailable else { return }
        if on {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
