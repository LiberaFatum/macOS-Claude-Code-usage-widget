import Foundation

/// Login item handling via a plain LaunchAgent plist.
///
/// `SMAppService` needs a signed bundle to behave predictably; this app is built
/// and ad-hoc signed locally, so a user-owned LaunchAgent is the reliable route
/// and stays inspectable with a text editor.
enum LaunchAtLogin {
    static let label = "com.liberafatum.claude-usage-widget"

    static var logURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/ClaudeUsage.log")
    }

    static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    /// Path of the running executable inside the .app bundle.
    private static var executablePath: String {
        Bundle.main.executableURL?.path ?? CommandLine.arguments[0]
    }

    static var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    @discardableResult
    static func set(_ enabled: Bool) -> Bool {
        enabled ? enable() : disable()
    }

    private static func enable() -> Bool {
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executablePath],
            "RunAtLoad": true,
            "KeepAlive": false,
            "ProcessType": "Interactive",
            "StandardOutPath": logURL.path,
            "StandardErrorPath": logURL.path
        ]
        do {
            try FileManager.default.createDirectory(
                at: plistURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: plistURL, options: .atomic)
            launchctl(["bootout", "gui/\(getuid())/\(label)"])   // ignore failure when not loaded
            return launchctl(["bootstrap", "gui/\(getuid())", plistURL.path])
        } catch {
            NSLog("ClaudeUsage: failed to write LaunchAgent: \(error)")
            return false
        }
    }

    private static func disable() -> Bool {
        launchctl(["bootout", "gui/\(getuid())/\(label)"])
        try? FileManager.default.removeItem(at: plistURL)
        return true
    }

    @discardableResult
    private static func launchctl(_ arguments: [String]) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = arguments
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }
}
