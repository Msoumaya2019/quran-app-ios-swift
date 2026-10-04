import SwiftUI

struct FriendsView: View {
    @EnvironmentObject var library: FriendsLibrary
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var network: ConnectivityService
    @State private var search = ""
    @State private var filter = "all"
    @State private var adding = false
    @State private var code = ""
    @State private var sending = false
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                Text("Mes amis").font(theme.title(.title)).foregroundStyle(theme.accent)
                Text("Apprenez et progressez ensemble").font(.subheadline).foregroundStyle(theme.muted)
                AppCard {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(theme.muted)
                        TextField("Rechercher un ami…", text: $search).accessibilityIdentifier("friends.search")
                        Button { adding = true } label: { Image(systemName: "plus").frame(width: 44, height: 44) }.accessibilityLabel("Ajouter un ami")
                    }
                }
                Picker("Afficher", selection: $filter) {
                    Text("Tous").tag("all"); Text("En ligne").tag("online"); Text("Demandes").tag("requests")
                }.pickerStyle(.segmented).accessibilityIdentifier("friends.filter")
                if let invite = library.snapshot?.profile["invite_code"].string {
                    HStack { Text("Mon code : \(invite)").font(.caption); Spacer(); ShareLink(item: invite) { Image(systemName: "square.and.arrow.up").frame(width: 44, height: 44) }.accessibilityLabel("Partager mon code ami") }.foregroundStyle(theme.muted)
                }
                if let message = library.message { Text(message).font(.caption).foregroundStyle(theme.muted) }
                let items = library.snapshot?.items(search: search, filter: filter) ?? []
                if items.isEmpty {
                    ContentUnavailableView(filter == "requests" ? "Aucune demande" : "Aucun ami affiché", systemImage: "person.2", description: Text(library.loading ? "Actualisation des amis…" : "Ajoute un ami avec son code ou change les filtres."))
                }
                ForEach(items) { item in
                    AppCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 12) {
                                Text(String(item.name.prefix(1))).font(.headline).foregroundStyle(theme.accent).frame(width: 44, height: 44).background(theme.accent.opacity(0.08), in: Circle())
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name).font(theme.title(.headline)).foregroundStyle(theme.text)
                                    Text(item.status == "pending" ? (item.incoming ? "Demande reçue" : "En attente de sa réponse") : item.online && !network.isOffline ? "En ligne" : "Ami").font(.caption).foregroundStyle(theme.muted)
                                }
                                Spacer()
                                if item.online && !network.isOffline { Circle().fill(theme.review).frame(width: 8, height: 8).accessibilityLabel("En ligne") }
                            }
                            if item.incoming && item.status == "pending" {
                                HStack {
                                    Button("Accepter") { respond(item, accept: true) }.buttonStyle(PrimaryButtonStyle())
                                    Button("Refuser") { respond(item, accept: false) }.frame(maxWidth: .infinity, minHeight: 44)
                                }.disabled(sending || network.isOffline)
                            }
                        }
                    }.accessibilityIdentifier("friends.item.\(item.id)")
                }
            }.padding(16)
        }.background(theme.background)
            .refreshable { await library.refresh() }
            .task { library.select(store.identity?.id); await library.refresh() }
            .sheet(isPresented: $adding) {
                NavigationStack {
                    Form {
                        Section("Code de ton ami") { TextField("Code d’invitation", text: $code).textInputAutocapitalization(.characters).autocorrectionDisabled() }
                        if network.isOffline { Text("Connexion nécessaire pour envoyer une demande.").font(.caption) }
                        if let message = library.message { Text(message).font(.caption) }
                        Button("Envoyer la demande") {
                            sending = true
                            Task { let confirmed = await library.request(code: code); sending = false; if confirmed { code = ""; adding = false } }
                        }.disabled(sending || network.isOffline || code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }.navigationTitle("Ajouter un ami").navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fermer") { adding = false } } }
                }.tint(theme.accent).presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
            }
    }
    private func respond(_ item: FriendItem, accept: Bool) {
        sending = true; Task { _ = await library.respond(item, accept: accept); sending = false }
    }
}
