import Foundation

/// Živé načtení limitů z toho samého endpointu, který volá Claude Code.
/// Bez něj se čeká, až Claude Code sám přepíše cache v `~/.claude.json`.
enum UsageAPI {
    static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    enum Failure: Error, CustomStringConvertible {
        case noToken
        case expiredToken(Date)
        case unauthorized
        case rateLimited(TimeInterval?)
        case http(Int)
        case transport(String)
        case malformed

        var description: String {
            switch self {
            case .noToken: return "token nenalezen"
            case .expiredToken: return "token vypršel, obnoví ho spuštění Claude Code"
            case .unauthorized: return "token odmítnut, obnoví ho spuštění Claude Code"
            case .rateLimited: return "endpoint omezuje četnost dotazů"
            case .http(let code): return "HTTP \(code)"
            case .transport(let message): return message
            case .malformed: return "neznámý formát odpovědi"
            }
        }

        /// Jak dlouho počkat, než se zkusí další dotaz.
        var backoff: TimeInterval {
            switch self {
            case .rateLimited(let after): return after ?? 900
            case .noToken: return 3600
            // Token si obnovuje jen Claude Code, dřív než za půl hodiny nemá smysl zkoušet.
            case .expiredToken, .unauthorized: return 1800
            default: return 300
            }
        }
    }

    /// Čtení tokenu může vyvolat dialog Keychainu, který blokuje volající vlákno,
    /// proto se celé volání odsouvá mimo hlavní vlákno.
    /// Hlavičky o limitu četnosti z poslední odpovědi, pro --test-api.
    static var lastRateLimitHeaders: [String: String] = [:]

    static func fetch(completion: @escaping (Result<UsageSnapshot, Failure>) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            switch Credentials.accessToken() {
            case .token(let token):
                send(token: token, completion: completion)
            case .expired(let since):
                completion(.failure(.expiredToken(since)))
            case .unavailable:
                NSLog("ClaudeUsage: token nenačten, %@", Credentials.diagnosis)
                completion(.failure(.noToken))
            }
        }
    }

    private static func send(token: String, completion: @escaping (Result<UsageSnapshot, Failure>) -> Void) {
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
            let http = response as? HTTPURLResponse
            let status = http?.statusCode ?? 0
            if let fields = http?.allHeaderFields as? [String: String] {
                lastRateLimitHeaders = fields.filter {
                    let key = $0.key.lowercased()
                    return key.contains("ratelimit") || key.contains("retry-after")
                }
            }
            // Loguje se jen to, co nevyšlo, ať soubor nebobtná řádkem za minutu.
            if status != 200 {
                NSLog("ClaudeUsage: /api/oauth/usage -> HTTP %d (%@)", status, Credentials.lastSource)
            }
            if status == 429 {
                let retryAfter = (http?.value(forHTTPHeaderField: "Retry-After")).flatMap(TimeInterval.init)
                completion(.failure(.rateLimited(retryAfter)))
                return
            }
            if status == 401 || status == 403 {
                // Token přestal platit. Zahodí se z paměti, ale nové čtení Keychainu
                // hlídá vlastní strop, aby uživateli neskákal dialog s heslem.
                Credentials.invalidate()
                completion(.failure(.unauthorized))
                return
            }
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
