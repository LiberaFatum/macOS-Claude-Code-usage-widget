import Foundation
import Security

/// Přístupový token Claude Code, aby šlo limity načíst rovnou z API.
///
/// Claude Code ho drží buď v souboru `~/.claude/.credentials.json`, nebo v Keychainu.
/// Čtení z Keychainu vyvolá systémový dialog, uživatel ho musí povolit.
enum Credentials {
    private static let keychainServices = ["Claude Code-credentials", "Claude Code"]

    static var fileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/.credentials.json")
    }

    static func accessToken() -> String? {
        if let data = try? Data(contentsOf: fileURL), let token = parse(data) { return token }
        for service in keychainServices {
            if let data = keychainData(service: service), let token = parse(data) { return token }
        }
        return nil
    }

    private static func parse(_ data: Data) -> String? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        if let oauth = root["claudeAiOauth"] as? [String: Any],
           let token = oauth["accessToken"] as? String, !token.isEmpty {
            return token
        }
        return (root["accessToken"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    }

    private static func keychainData(service: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }
}
