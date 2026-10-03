import SwiftUI

struct AuthView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var theme: ThemeManager
    @State private var email = ""
    @State private var password = ""
    @State private var register = false
    @State private var busy = false
    @State private var error: String?
    @State private var notice: String?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(theme.hero).resizable().scaledToFill().frame(height: 150).clipped().clipShape(RoundedRectangle(cornerRadius: 22))
                    Text("Apprendre le Coran").font(theme.title(.title)).foregroundStyle(theme.accent)
                    Text(register ? "Créer mon compte" : "Retrouve ton compte et ta progression").foregroundStyle(theme.muted)
                    AppCard {
                        VStack(spacing: 14) {
                            TextField("Adresse e-mail", text: $email).textContentType(.username).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("auth.email").frame(minHeight: 44)
                            Divider()
                            SecureField("Mot de passe", text: $password).textContentType(register ? .newPassword : .password).accessibilityIdentifier("auth.password").frame(minHeight: 44)
                        }
                    }
                    if let error { Text(error).font(.callout).foregroundStyle(.red).accessibilityIdentifier("auth.error") }
                    if let notice { Text(notice).font(.callout).foregroundStyle(theme.review) }
                    Button { Task { await submit() } } label: { HStack { if busy { ProgressView().tint(.white) }; Text(register ? "Créer mon compte" : "Se connecter") } }.buttonStyle(PrimaryButtonStyle()).disabled(busy || email.isEmpty || password.isEmpty).accessibilityIdentifier("auth.submit")
                    Button(register ? "J’ai déjà un compte" : "Créer un compte") { register.toggle(); error = nil; notice = nil }.frame(minHeight: 44).disabled(busy)
                    Button("Mot de passe oublié ?") { Task { await reset() } }.frame(minHeight: 44).disabled(busy || email.isEmpty)
                    Text("Une première connexion nécessite Internet. Ensuite, les données déjà chargées restent consultables hors connexion.").font(.footnote).foregroundStyle(theme.muted)
                }.padding(20)
            }.background(theme.background).navigationTitle("Bienvenue").navigationBarTitleDisplayMode(.inline)
        }
    }
    private func submit() async {
        busy = true; error = nil; notice = nil; defer { busy = false }
        do {
            if register {
                let connected = try await store.signUp(email: email, password: password)
                if !connected { notice = "Vérifie tes e-mails pour confirmer ton compte." }
            } else { try await store.signIn(email: email, password: password) }
            password = ""
        } catch { self.error = "Connexion impossible : " + error.localizedDescription; HapticService.error() }
    }
    private func reset() async {
        busy = true; error = nil; defer { busy = false }
        do { try await store.resetPassword(email: email); notice = "Si ce compte existe, un lien de récupération sera envoyé." } catch { self.error = error.localizedDescription }
    }
}
struct PasswordRecoveryView: View {
    @EnvironmentObject var store: AppStore
    @State private var password = ""
    @State private var confirmation = ""
    @State private var error: String?
    @State private var busy = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Nouveau mot de passe") {
                    SecureField("Mot de passe", text: $password).textContentType(.newPassword)
                    SecureField("Confirmer", text: $confirmation).textContentType(.newPassword)
                }
                if let error { Text(error).foregroundStyle(.red) }
                Button("Enregistrer") { Task { busy = true; defer { busy = false }; do { try await store.updatePassword(password) } catch { self.error = error.localizedDescription } } }.disabled(busy || password.count < 6 || password != confirmation)
            }.navigationTitle("Récupération du compte")
        }.interactiveDismissDisabled()
    }
}
