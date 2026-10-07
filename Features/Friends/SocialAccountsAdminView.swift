import SwiftUI

struct SocialAccountsAdminView: View {
    @EnvironmentObject private var library: ModerationLibrary
    @EnvironmentObject private var theme: ThemeManager
    @State private var search = ""
    var body: some View {
        List {
            Text("Gère l’accès aux échanges entre amis. Une suspension sociale ne supprime ni le compte ni sa progression.")
                .font(.caption).foregroundStyle(theme.muted)
            if library.loading { ProgressView("Chargement…") }
            if let message = library.message { Text(message).font(.caption) }
            ForEach(Array(library.items.filter { search.isEmpty || ($0["display_name"].string ?? "").localizedStandardContains(search) }.enumerated()), id: \.offset) { _, row in
                NavigationLink { SocialAccountDetail(row: row) } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(row["display_name"].string ?? "Utilisateur").font(.headline)
                        Text(row["protected"].bool == true ? "Compte protégé" : row["suspension"] == .null ? "Accès social actif" : "Suspension enregistrée")
                            .font(.caption).foregroundStyle(theme.muted)
                    }.padding(.vertical, 4)
                }
            }
            if library.hasMore { Button("Charger la suite") { Task { await library.load(.members, more: true) } }.disabled(library.loading) }
        }.navigationTitle("Comptes · espace amis").navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Rechercher parmi les comptes chargés")
            .task { await library.load(.members) }.refreshable { await library.load(.members) }
    }
}

private struct SocialAccountDetail: View {
    let row: JSONValue
    @EnvironmentObject private var library: ModerationLibrary
    @State private var reason = ""
    @State private var duration = 1
    @State private var confirmation = false
    @State private var openingOwner: UUID?
    private var current: JSONValue { library.items.first { $0["id"] == row["id"] } ?? row }
    var body: some View {
        Form {
            if openingOwner == library.account, openingOwner != nil {
                Section("Compte") {
                    Text(current["display_name"].string ?? "Utilisateur")
                    Text(current["id"].string ?? "").font(.caption).textSelection(.enabled)
                }
                if current["protected"].bool == true { Text("Ce compte est protégé.") }
                else {
                    if current["suspension"] != .null {
                        Section("Suspension enregistrée") {
                            Text(current["suspension"]["reason"].string ?? "")
                            Text(current["suspension"]["suspended_until"].string ?? "Sans date de fin").font(.caption)
                            Button("Rétablir l’accès social") { confirmation = true }
                        }
                    } else {
                        Section("Suspendre l’accès social") {
                            TextField("Motif", text: $reason, axis: .vertical).lineLimit(2...5)
                            Picker("Durée", selection: $duration) {
                                Text("24 heures").tag(1); Text("7 jours").tag(7); Text("Sans date de fin").tag(0)
                            }
                            Button("Suspendre", role: .destructive) { confirmation = true }
                                .disabled(!(2...500).contains(reason.trimmingCharacters(in: .whitespacesAndNewlines).count))
                        }
                    }
                }
                if let message = library.message { Text(message).font(.caption) }
            } else { Text("Cette session administrateur n’est plus active.") }
        }.disabled(library.busy).navigationTitle("Accès social")
            .task { openingOwner = library.account }
            .confirmationDialog("Confirmer la modification de l’accès social ?", isPresented: $confirmation, titleVisibility: .visible) {
                Button("Confirmer", role: current["suspension"] == .null ? .destructive : nil) {
                    guard openingOwner == library.account else { return }
                    Task {
                        let restoring = current["suspension"] != .null
                        let until = duration == 0 ? nil : Date().addingTimeInterval(Double(duration) * 86400)
                        _ = await library.suspension(current, reason: restoring ? nil : reason, until: restoring ? nil : until)
                    }
                }
                Button("Annuler", role: .cancel) {}
            }
    }
}
