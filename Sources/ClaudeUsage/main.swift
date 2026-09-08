import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var usage: UsageSnapshot?
    private var stats: StatsSnapshot?

    private let repoURL = URL(string: "https://github.com/LiberaFatum/macOS-Claude-Code-usage-widget")!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // launchd and a manual open can both fire; a second copy would just add
        // a duplicate menu bar icon.
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        if !others.isEmpty {
            NSApp.terminate(nil)
            return
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.imagePosition = .imageLeading
        rebuildMenu()
        refresh()
        restartTimer()
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
    }

    // MARK: - Data

    private func refresh() {
        usage = UsageReader.read()
        stats = StatsReader.read()
        updateStatusTitle()
    }

    private func restartTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: Preferences.refreshInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        timer?.tolerance = 5
    }

    private func updateStatusTitle() {
        guard let button = statusItem.button else { return }

        let session = usage?.session?.percent
        let weekly = usage?.weeklyAll?.percent

        var text: String
        var tint: Double?

        switch Preferences.menuBarMode {
        case .session:
            text = session.map { "\(Int($0.rounded()))%" } ?? "—"
            tint = session
        case .weekly:
            text = weekly.map { "\(Int($0.rounded()))%" } ?? "—"
            tint = weekly
        case .both:
            let s = session.map { "\(Int($0.rounded()))%" } ?? "—"
            let w = weekly.map { "\(Int($0.rounded()))%" } ?? "—"
            text = "\(s) · \(w)"
            tint = [session, weekly].compactMap { $0 }.max()
        case .highest:
            let highest = [session, weekly].compactMap { $0 }.max()
            text = highest.map { "\(Int($0.rounded()))%" } ?? "—"
            tint = highest
        }

        // Only shout when it matters; below 80 % the title stays in the normal menu-bar colour.
        var attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        ]
        if let tint, tint >= 80 {
            attributes[.foregroundColor] = tint >= 95 ? NSColor.systemRed : NSColor.systemOrange
        }
        button.attributedTitle = NSAttributedString(string: text, attributes: attributes)

        if Preferences.showIcon {
            let symbol = NSImage(systemSymbolName: "gauge.with.dots.needle.33percent", accessibilityDescription: "Claude usage")
            symbol?.isTemplate = true
            button.image = symbol
        } else {
            button.image = nil
        }

        button.toolTip = tooltip()
    }

    private func tooltip() -> String {
        guard let usage else { return "Claude Code usage — no data yet" }
        var lines = usage.limits.map { "\($0.title): \(Int($0.percent.rounded()))% (resets in \(Fmt.countdown(to: $0.resetsAt)))" }
        lines.append("Updated \(Fmt.ago(usage.fetchedAt))")
        return lines.joined(separator: "\n")
    }

    // MARK: - Menu

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.delegate = self

        let about = NSMenuItem(title: "About Claude Usage…", action: #selector(openRepo), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        menu.addItem(.separator())

        let content = NSMenuItem()
        let hosting = NSHostingView(rootView: UsageContentView(usage: usage, stats: stats))
        hosting.frame.size = hosting.fittingSize
        content.view = hosting
        menu.addItem(content)

        menu.addItem(.separator())

        let refreshItem = NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(preferencesItem())
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func preferencesItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Preferences", action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        submenu.addItem(sectionHeader("Menu bar shows"))
        for mode in MenuBarMode.allCases {
            let entry = NSMenuItem(title: mode.label, action: #selector(setMode(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = mode.rawValue
            entry.state = Preferences.menuBarMode == mode ? .on : .off
            submenu.addItem(entry)
        }

        submenu.addItem(.separator())
        submenu.addItem(sectionHeader("Refresh every"))
        for interval in Preferences.refreshIntervals {
            let title = interval < 60 ? "\(Int(interval)) seconds" : "\(Int(interval / 60)) minute\(interval >= 120 ? "s" : "")"
            let entry = NSMenuItem(title: title, action: #selector(setInterval(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = interval
            entry.state = Preferences.refreshInterval == interval ? .on : .off
            submenu.addItem(entry)
        }

        submenu.addItem(.separator())
        submenu.addItem(sectionHeader("Chart range"))
        for days in [14, 30, 60] {
            let entry = NSMenuItem(title: "\(days) days", action: #selector(setChartDays(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = days
            entry.state = Preferences.chartDays == days ? .on : .off
            submenu.addItem(entry)
        }

        submenu.addItem(.separator())

        let icon = NSMenuItem(title: "Show menu bar icon", action: #selector(toggleIcon), keyEquivalent: "")
        icon.target = self
        icon.state = Preferences.showIcon ? .on : .off
        submenu.addItem(icon)

        let login = NSMenuItem(title: "Start at login", action: #selector(toggleLoginItem), keyEquivalent: "")
        login.target = self
        login.state = LaunchAtLogin.isEnabled ? .on : .off
        submenu.addItem(login)

        item.submenu = submenu
        return item
    }

    private func sectionHeader(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    func menuWillOpen(_ menu: NSMenu) {
        refresh()
        rebuildMenu()
    }

    // MARK: - Actions

    @objc private func refreshNow() {
        refresh()
        rebuildMenu()
    }

    @objc private func openRepo() {
        NSWorkspace.shared.open(repoURL)
    }

    @objc private func setMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let mode = MenuBarMode(rawValue: raw) else { return }
        Preferences.menuBarMode = mode
        updateStatusTitle()
        rebuildMenu()
    }

    @objc private func setInterval(_ sender: NSMenuItem) {
        guard let interval = sender.representedObject as? TimeInterval else { return }
        Preferences.refreshInterval = interval
        restartTimer()
        rebuildMenu()
    }

    @objc private func setChartDays(_ sender: NSMenuItem) {
        guard let days = sender.representedObject as? Int else { return }
        Preferences.chartDays = days
        rebuildMenu()
    }

    @objc private func toggleIcon() {
        Preferences.showIcon.toggle()
        updateStatusTitle()
        rebuildMenu()
    }

    @objc private func toggleLoginItem() {
        LaunchAtLogin.set(!LaunchAtLogin.isEnabled)
        rebuildMenu()
    }
}

// Small CLI surface, used by install.sh and to regenerate the README screenshot.
switch CommandLine.arguments.dropFirst().first {
case "--enable-login-item":
    LaunchAtLogin.set(true)
    print(LaunchAtLogin.isEnabled ? "Login item enabled." : "Failed to enable login item.")
    exit(LaunchAtLogin.isEnabled ? 0 : 1)
case "--disable-login-item":
    LaunchAtLogin.set(false)
    print("Login item disabled.")
    exit(0)
case "--render-preview":
    let path = CommandLine.arguments.dropFirst(2).first ?? "preview.png"
    MainActor.assumeIsolated { Preview.render(to: path) }
    exit(0)
default:
    break
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
