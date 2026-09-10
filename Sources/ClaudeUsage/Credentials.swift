import Foundation
import Security

/// Přístupový token Claude Code, aby šlo limity načíst rovnou z API.
///
/// Claude Code ho drží buď v souboru `~/.claude/.credentials.json`, nebo v Keychainu.
/// Čtení z Keychainu vyvolá systémový dialog, uživatel ho musí povolit.
enum Credentials {
    private static let keychainServices = ["Claude Code-credentials", "Claude Code"]

    /// Vlastní položka widgetu. Vytváří ji sama aplikace, takže je v jejím seznamu
    /// povolených a systém se na heslo neptá. Claude Code do ní nesahá, takže ji
    /// nepřepíše ani při obnově svého tokenu.
    private static let ownService = "com.liberafatum.claude-usage-widget"
    private static let ownAccount = "usage-token"

    /// Token se drží v paměti procesu. Každé čtení Keychainu může vyvolat systémový
    /// dialog, takže se sahá dolů jen jednou za běh a znovu až když token přestane platit.
    private static let lock = NSLock()
    private static var cached: String?
    private static var cachedExpiry: Date?
    private static var lastRead: Date?

    /// Když token nevyjde, nesmí se sáhnout dolů hned znovu, jinak dialog s heslem
    /// naskakuje pořád dokola.
    private static let minimumReadInterval: TimeInterval = 900

    /// Poslední výsledek hledání v Keychainu, pro diagnostiku.
    private(set) static var lastStatus: OSStatus = errSecSuccess
    private(set) static var lastSource = "nic"

    static var fileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/.credentials.json")
    }

    enum Outcome {
        case token(String)
        /// Token existuje, ale vypršel. Obnovit ho umí jen Claude Code.
        case expired(Date)
        /// Token nenalezen, nebo se do Keychainu teď nesmí sáhnout.
        case unavailable
    }

    static func accessToken() -> Outcome {
        lock.lock()
        defer { lock.unlock() }

        if let token = cached {
            guard let expiry = cachedExpiry, expiry <= Date() else { return .token(token) }
            // Vypršelý token zahodit, ať se dole zkusí načíst ten, který mezitím
            // mohl obnovit Claude Code.
            cached = nil
            cachedExpiry = nil
            if let last = lastRead, Date().timeIntervalSince(last) < minimumReadInterval {
                return .expired(expiry)
            }
        }

        if let last = lastRead, Date().timeIntervalSince(last) < minimumReadInterval {
            return .unavailable
        }
        lastRead = Date()

        // Vlastní token má přednost, jeho čtení nikdy nevyvolá dialog.
        if let own = ownToken() {
            return store((own, nil), source: "vlastní token")
        }
        if let data = try? Data(contentsOf: fileURL), let parsed = parse(data) {
            return store(parsed, source: "soubor")
        }
        for service in keychainServices {
            let (data, status) = keychainData(service: service)
            lastStatus = status
            if let data, let parsed = parse(data) {
                return store(parsed, source: "keychain:\(service)")
            }
        }
        lastSource = "nenalezeno"
        return .unavailable
    }

    /// Zahodí token z paměti. Nové čtení Keychainu proběhne až po `minimumReadInterval`.
    static func invalidate() {
        lock.lock()
        cached = nil
        cachedExpiry = nil
        lock.unlock()
    }

    static var diagnosis: String {
        "zdroj=\(lastSource) OSStatus=\(lastStatus) (\(SecCopyErrorMessageString(lastStatus, nil) as String? ?? "?"))"
    }

    private static func store(_ parsed: (token: String, expiry: Date?), source: String) -> Outcome {
        cached = parsed.token
        cachedExpiry = parsed.expiry
        lastSource = source
        if let expiry = parsed.expiry, expiry <= Date() { return .expired(expiry) }
        return .token(parsed.token)
    }

    private static func parse(_ data: Data) -> (token: String, expiry: Date?)? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        let holder = (root["claudeAiOauth"] as? [String: Any]) ?? root
        guard let token = holder["accessToken"] as? String, !token.isEmpty else { return nil }

        // expiresAt bývá v milisekundách, chybět ale může, pak se platnost neřeší.
        var expiry: Date?
        if let raw = holder["expiresAt"] as? Double ?? (holder["expiresAt"] as? Int).map(Double.init) {
            expiry = Date(timeIntervalSince1970: raw > 1_000_000_000_000 ? raw / 1000 : raw)
        }
        return (token, expiry)
    }

    // MARK: - Vlastní token

    static var hasOwnToken: Bool { ownToken() != nil }

    private static func ownToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: ownService,
            kSecAttrAccount as String: ownAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else { return nil }
        return token
    }

    /// Uloží token vydaný příkazem "claude setup-token".
    @discardableResult
    static func saveOwnToken(_ token: String) -> OSStatus {
        lock.lock()
        cached = nil
        cachedExpiry = nil
        lastRead = nil
        lock.unlock()

        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else { return errSecParam }

        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: ownService,
            kSecAttrAccount as String: ownAccount
        ]
        // Po prvním odemčení po startu, ať widget funguje i bez zásahu uživatele.
        var attributes = base
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        attributes[kSecAttrLabel as String] = "Claude Usage widget token"

        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecDuplicateItem {
            return SecItemUpdate(base as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        }
        return status
    }

    @discardableResult
    static func deleteOwnToken() -> OSStatus {
        lock.lock()
        cached = nil
        cachedExpiry = nil
        lastRead = nil
        lock.unlock()

        return SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: ownService,
            kSecAttrAccount as String: ownAccount
        ] as CFDictionary)
    }

    private static func keychainData(service: String) -> (Data?, OSStatus) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        return (status == errSecSuccess ? item as? Data : nil, status)
    }
}
