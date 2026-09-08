import AppKit
import SwiftUI

// Malé CLI, které používá install.sh a generování snímku do README.
switch CommandLine.arguments.dropFirst().first {
case "--enable-login-item":
    LaunchAtLogin.set(true)
    print(LaunchAtLogin.isEnabled ? "Spouštění po přihlášení zapnuto." : "Nepodařilo se zapnout spouštění po přihlášení.")
    exit(LaunchAtLogin.isEnabled ? 0 : 1)
case "--disable-login-item":
    LaunchAtLogin.set(false)
    print("Spouštění po přihlášení vypnuto.")
    exit(0)
case "--render-preview":
    let path = CommandLine.arguments.dropFirst(2).first ?? "preview.png"
    MainActor.assumeIsolated { Preview.render(to: path) }
    exit(0)
default:
    break
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var watchTimer: Timer?
    private var usage: UsageSnapshot?
    private var stats: StatsSnapshot?
    private var seenModificationDates: [String: Date] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        // launchd i ruční spuštění mohou nastat současně, druhá kopie by přidala
        // duplicitní ikonu do lišty.
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
        startWatching()
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        watchTimer?.invalidate()
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
        timer?.tolerance = 2
    }

    /// Sleduje čas změny obou souborů a načte je hned, jak je Claude Code přepíše.
    /// Samotná čerstvost dat tím ale nevzroste, viz `UsageSnapshot.age`.
    private func startWatching() {
        watchTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            var changed = false
            for url in [UsageReader.path, StatsReader.path] {
                let modified = (try? FileManager.default
                    .attributesOfItem(atPath: url.path)[.modificationDate] as? Date) ?? nil
                guard let modified else { continue }
                if self.seenModificationDates[url.path] != modified {
                    self.seenModificationDates[url.path] = modified
                    changed = true
                }
            }
            if changed { self.refresh() }
        }
        watchTimer?.tolerance = 0.3
    }

    private func updateStatusTitle() {
        guard let button = statusItem.button else { return }

        let session = usage?.session?.percent
        let weekly = usage?.weeklyAll?.percent

        var text: String
        var tint: Double?

        switch Preferences.menuBarMode {
        case .session:
            text = session.map { "\(Int($0.rounded())) %" } ?? "?"
            tint = session
        case .weekly:
            text = weekly.map { "\(Int($0.rounded())) %" } ?? "?"
            tint = weekly
        case .both:
            let s = session.map { "\(Int($0.rounded()))" } ?? "?"
            let w = weekly.map { "\(Int($0.rounded()))" } ?? "?"
            text = "\(s) · \(w) %"
            tint = [session, weekly].compactMap { $0 }.max()
        case .highest:
            let highest = [session, weekly].compactMap { $0 }.max()
            text = highest.map { "\(Int($0.rounded())) %" } ?? "?"
            tint = highest
        }

        // Pod 80 % zůstává text v běžné barvě lišty, výš už má smysl upozornit.
        var attributes: [NSAttributedString.Key: Any] = [
            .font: Fmt.monoNS(12),
            .baselineOffset: -1.0
        ]
        if let tint, tint >= 80 {
            attributes[.foregroundColor] = tint >= 95 ? NSColor.systemRed : NSColor.systemOrange
        }
        button.attributedTitle = NSAttributedString(string: text, attributes: attributes)
        button.image = Preferences.showIcon ? Mascot.statusBarImage() : nil
        button.toolTip = tooltip()
    }

    private func tooltip() -> String {
        guard let usage else { return "Spotřeba Claude Code: zatím žádná data" }
        var lines = usage.limits.map {
            "\($0.title): \(Int($0.percent.rounded())) % (reset za \(Fmt.countdown(to: $0.resetsAt)))"
        }
        lines.append("Aktualizováno \(Fmt.ago(usage.fetchedAt))")
        return lines.joined(separator: "\n")
    }

    // MARK: - Menu

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.delegate = self

        let content = NSMenuItem()
        let hosting = NSHostingView(rootView: UsageContentView(usage: usage, stats: stats))
        hosting.frame.size = hosting.fittingSize
        content.view = hosting
        menu.addItem(content)

        menu.addItem(.separator())

        let refreshItem = NSMenuItem(title: "Načíst znovu", action: #selector(refreshNow), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(preferencesItem())
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Ukončit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    private func preferencesItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Nastavení", action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        submenu.addItem(sectionHeader("V liště zobrazit"))
        for mode in MenuBarMode.allCases {
            let entry = NSMenuItem(title: mode.label, action: #selector(setMode(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = mode.rawValue
            entry.state = Preferences.menuBarMode == mode ? .on : .off
            submenu.addItem(entry)
        }

        submenu.addItem(.separator())
        submenu.addItem(sectionHeader("Načítat každých"))
        for interval in Preferences.refreshIntervals {
            let title = interval < 60 ? "\(Int(interval)) s" : "\(Int(interval / 60)) min"
            let entry = NSMenuItem(title: title, action: #selector(setInterval(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = interval
            entry.state = Preferences.refreshInterval == interval ? .on : .off
            submenu.addItem(entry)
        }

        submenu.addItem(.separator())
        submenu.addItem(sectionHeader("Rozsah grafu"))
        for days in [14, 30, 60] {
            let entry = NSMenuItem(title: "\(days) dní", action: #selector(setChartDays(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = days
            entry.state = Preferences.chartDays == days ? .on : .off
            submenu.addItem(entry)
        }

        submenu.addItem(.separator())

        let icon = NSMenuItem(title: "Ikona v liště", action: #selector(toggleIcon), keyEquivalent: "")
        icon.target = self
        icon.state = Preferences.showIcon ? .on : .off
        submenu.addItem(icon)

        let login = NSMenuItem(title: "Spouštět po přihlášení", action: #selector(toggleLoginItem), keyEquivalent: "")
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

    // MARK: - Akce

    @objc private func refreshNow() {
        refresh()
        rebuildMenu()
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

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
