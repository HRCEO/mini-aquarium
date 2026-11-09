import AppKit

if ["--snapshot", "--icon", "--dmg-bg"].contains(where: CommandLine.arguments.contains) {
    MainActor.assumeIsolated { Snapshot.run(arguments: CommandLine.arguments) }
}

if let flag = CommandLine.arguments.firstIndex(of: "--set-file-icon"), CommandLine.arguments.count > flag + 2 {
    // 빌드 스크립트용: 파일(.dmg)에 아이콘을 입힌다.
    let image = NSImage(contentsOfFile: CommandLine.arguments[flag + 2])
    exit(image.map { NSWorkspace.shared.setIcon($0, forFile: CommandLine.arguments[flag + 1]) ? 0 : 1 } ?? 1)
}

if CommandLine.arguments.contains("--uninstall") {
    // 삭제 전 정리: 로그인 시 자동 실행 등록을 해제한다 (scripts/uninstall.sh가 호출).
    try? LaunchAtLogin.set(false)
    exit(0)
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
