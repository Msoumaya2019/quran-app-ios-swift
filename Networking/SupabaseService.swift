import Foundation
import Supabase

enum ConfigurationError: LocalizedError {
    case missing
    var errorDescription: String? { "La connexion Supabase n’est pas configurée pour cette compilation." }
}
struct BackendConfiguration {
    let url: URL
    let publicKey: String
    static func load(bundle: Bundle = .main) throws -> BackendConfiguration {
        let file = bundle.url(forResource: "Backend.local", withExtension: "plist") ?? bundle.url(forResource: "Backend", withExtension: "plist")
        guard let file, let data = try? Data(contentsOf: file), let values = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String], let raw = values["SUPABASE_URL"], let url = URL(string: raw), url.scheme == "https", let key = values["SUPABASE_PUBLIC_KEY"], !key.isEmpty else { throw ConfigurationError.missing }
        return BackendConfiguration(url: url, publicKey: key)
    }
    func client() -> SupabaseClient {
        let settings = URLSessionConfiguration.default
        // Requests still fail promptly offline; an upload may need more time to finish.
        settings.timeoutIntervalForRequest = 8; settings.timeoutIntervalForResource = 120
        settings.waitsForConnectivity = false
        return SupabaseClient(supabaseURL: url, supabaseKey: publicKey, options: .init(auth: .init(storage: KeychainVault(), redirectToURL: URL(string: "corannative://auth"), storageKey: "native-supabase-session", autoRefreshToken: false), global: .init(session: URLSession(configuration: settings))))
    }
}
