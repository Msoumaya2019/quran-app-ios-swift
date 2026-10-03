import Foundation
import Supabase

@MainActor protocol AuthGateway {
    var cachedIdentity: AccountIdentity? { get }
    func signIn(email: String, password: String) async throws -> AccountIdentity
    func signUp(email: String, password: String) async throws -> AccountIdentity?
    func refresh() async throws -> AccountIdentity
    func signOut() async throws
    func resetPassword(email: String) async throws
    func receive(url: URL) async throws -> AccountIdentity
    func changePassword(_ password: String) async throws
}
@MainActor final class AuthService: AuthGateway {
    let client: SupabaseClient?
    private let vault = KeychainVault()
    private let identityKey = "offline-identity"
    init(client: SupabaseClient?) { self.client = client }
    var cachedIdentity: AccountIdentity? {
        guard let data = try? vault.retrieve(key: identityKey) else { return nil }
        return try? JSONDecoder().decode(AccountIdentity.self, from: data)
    }
    private func requireClient() throws -> SupabaseClient { guard let client else { throw ConfigurationError.missing }; return client }
    private func persist(_ user: User) throws -> AccountIdentity {
        let identity = AccountIdentity(id: user.id, email: user.email)
        try vault.store(key: identityKey, value: JSONEncoder().encode(identity)); return identity
    }
    func signIn(email: String, password: String) async throws -> AccountIdentity { try persist(try await requireClient().auth.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password).user) }
    func signUp(email: String, password: String) async throws -> AccountIdentity? {
        let response = try await requireClient().auth.signUp(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password, redirectTo: URL(string: "corannative://auth"))
        guard let session = response.session else { return nil }; return try persist(session.user)
    }
    func refresh() async throws -> AccountIdentity { try persist(try await requireClient().auth.session.user) }
    func signOut() async throws {
        // Local scope: never revoke the independent React Native session.
        try await requireClient().auth.signOut(scope: .local)
        try vault.remove(key: identityKey)
    }
    func resetPassword(email: String) async throws { try await requireClient().auth.resetPasswordForEmail(email.trimmingCharacters(in: .whitespacesAndNewlines), redirectTo: URL(string: "corannative://auth")) }
    func receive(url: URL) async throws -> AccountIdentity {
        guard url.scheme == "corannative", url.host == "auth" else { throw URLError(.badURL) }
        return try persist(try await requireClient().auth.session(from: url).user)
    }
    func changePassword(_ password: String) async throws { try await requireClient().auth.update(user: UserAttributes(password: password)) }
}
