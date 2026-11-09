import AppKit

if CommandLine.arguments.contains("--snapshot") || CommandLine.arguments.contains("--icon") {
    MainActor.assumeIsolated { Snapshot.run(arguments: CommandLine.arguments) }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
