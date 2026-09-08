import Foundation
import Security

/// Přístupový token Claude Code, aby šlo limity načíst rovnou z API.
///
/// Claude Code ho drží buď v souboru `~/.claude/.credentials.json`, nebo v Keychainu.
/// Čtení z Keychainu vyvolá systémový dialog, uživatel ho musí povolit.
enum Credentials {
    private static let keychainServices = ["Claude Code-credentials", "Claude Code"]

    /// Token se drží v paměti procesu. Každé čtení Keychainu může vyvolat systémový
    /// dialog, takže se sahá dolů jen jednou za běh a znovu až když token přestane platit.
    private static let lock = NSLock()
    private static var cached: String?

    /// Poslední výsledek hledání v Keychainu, pro diagnostiku.
    private(set) static var lastStatus: OSStatus = errSecSuccess
    private(set) static var lastSource = "nic"

    static var fileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/.credentials.json")
    }

    static func accessToken() -> String? {
        lock.lock()
        defer { lock.unlock() }
        if let cached { return cached }

        if let data = try? Data(contentsOf: fileURL), let token = parse(data) {
            cached = token
            lastSource = "soubor"
            return token
        }
        for service in keychainServices {
            let (data, status) = keychainData(service: service)
            lastStatus = status
            if let data, let token = parse(data) {
                cached = token
                lastSource = "keychain:\(service)"
                return token
            }
        }
        lastSource = "nenalezeno"
        return nil
    }

    static var diagnosis: String {
        "zdroj=\(lastSource) OSStatus=\(lastStatus) (\(SecCopyErrorMessageString(lastStatus, nil) as String? ?? "?"))"
    }

    /// Zahodí token z paměti, aby se po vypršení načetl znovu.
    static func invalidate() {
        lock.lock()
        cached = nil
        lock.unlock()
    }

    private static func parse(_ data: Data) -> String? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        if let oauth = root["claudeAiOauth"] as? [String: Any],
           let token = oauth["accessToken"] as? String, !token.isEmpty {
            return token
        }
        return (root["accessToken"] as? String).flatMap { $0.isEmpty ? nil : $0 }
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
