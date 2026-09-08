import Foundation

enum MenuBarMode: String, CaseIterable {
    case session
    case weekly
    case both
    case highest

    var label: String {
        switch self {
        case .session: return "Session (5 h)"
        case .weekly: return "Weekly"
        case .both: return "Session + Weekly"
        case .highest: return "Vyšší z obou"
        }
    }
}

enum Preferences {
    private static let defaults = UserDefaults.standard

    static let refreshIntervals: [TimeInterval] = [10, 30, 60, 300]

    static var menuBarMode: MenuBarMode {
        get { MenuBarMode(rawValue: defaults.string(forKey: "menuBarMode") ?? "") ?? .both }
        set { defaults.set(newValue.rawValue, forKey: "menuBarMode") }
    }

    static var refreshInterval: TimeInterval {
        get {
            let stored = defaults.double(forKey: "refreshInterval")
            return refreshIntervals.contains(stored) ? stored : 30
        }
        set { defaults.set(newValue, forKey: "refreshInterval") }
    }

    static var showIcon: Bool {
        get { defaults.object(forKey: "showIcon") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showIcon") }
    }

    /// Číst limity rovnou z /api/oauth/usage. Vyžaduje přístup k tokenu v Keychainu.
    static var liveAPI: Bool {
        get { defaults.object(forKey: "liveAPI") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "liveAPI") }
    }

    static var chartDays: Int {
        get {
            let stored = defaults.integer(forKey: "chartDays")
            return stored > 0 ? stored : 30
        }
        set { defaults.set(newValue, forKey: "chartDays") }
    }
}
