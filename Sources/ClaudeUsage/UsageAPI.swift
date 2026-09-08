import Foundation

/// Živé načtení limitů z toho samého endpointu, který volá Claude Code.
/// Bez něj se čeká, až Claude Code sám přepíše cache v `~/.claude.json`.
enum UsageAPI {
    static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    enum Failure: Error, CustomStringConvertible {
        case noToken
        case http(Int)
        case transport(String)
        case malformed

        var description: String {
            switch self {
            case .noToken: return "token nenalezen"
            case .http(let code): return "HTTP \(code)"
            case .transport(let message): return message
            case .malformed: return "neznámý formát odpovědi"
            }
        }
    }

    static func fetch(completion: @escaping (Result<UsageSnapshot, Failure>) -> Void) {
        guard let token = Credentials.accessToken() else {
            completion(.failure(.noToken))
            return
        }

        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 10
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(.transport(error.localizedDescription)))
                return
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else {
                completion(.failure(.http(status)))
                return
            }
            guard let data,
                  let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                completion(.failure(.malformed))
                return
            }
            // Odpověď může limity nést přímo, nebo zabalené v "utilization".
            let container = (root["utilization"] as? [String: Any]) ?? root
            let limits = UsageReader.limits(from: container)
            guard !limits.isEmpty else {
                completion(.failure(.malformed))
                return
            }
            completion(.success(UsageSnapshot(fetchedAt: Date(), limits: limits, source: .api)))
        }.resume()
    }
}
