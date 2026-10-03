import SwiftUI

enum MainTab: String, CaseIterable, Identifiable {
    case home = "Accueil", quran = "Coran", program = "Programme", progress = "Progrès", friends = "Amis"
    var id: String { rawValue }
    var icon: String {
        switch self { case .home: return "house"; case .quran: return "book"; case .program: return "calendar"; case .progress: return "chart.bar"; case .friends: return "person.2" }
    }
}
enum HomeRoute: String, Identifiable {
    case reading = "Lecture", learning = "Apprentissage", revision = "Révision", quiz = "Quiz", objective = "Mon objectif", report = "Signaler un problème"
    var id: String { rawValue }
}
struct PhasePlaceholder: View {
    let title: String
    var body: some View {
        ContentUnavailableView(title, systemImage: "hammer", description: Text("Cet écran sera migré dans une prochaine phase, après ta validation. Les données de l’application actuelle sont conservées."))
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline).accessibilityIdentifier("phase.placeholder")
    }
}
struct RootView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var network: ConnectivityService
    @State private var tab: MainTab = .home
    @State private var settings = false
    var body: some View {
        Group {
            if store.identity == nil { AuthView() }
            else {
                TabView(selection: $tab) {
                    ForEach(MainTab.allCases) { item in
                        NavigationStack {
                            Group {
                                if item == .home { HomeView(tab: $tab) }
                                else { PhasePlaceholder(title: item.rawValue) }
                            }
                            .toolbar {
                                ToolbarItem(placement: .topBarLeading) {
                                    HStack(spacing: 7) { Image(systemName: "book.closed").foregroundStyle(theme.gold); Text("Apprendre le Coran").font(theme.title(.headline)).foregroundStyle(theme.accent) }
                                }
                                ToolbarItem(placement: .topBarTrailing) {
                                    HStack(spacing: 0) {
                                        Button { settings = true } label: { Text(String(HomeProjection(snapshot: store.snapshot).name.prefix(1))).font(.headline).frame(width: 32, height: 32).background(theme.accent, in: Circle()).foregroundStyle(.white) }.frame(width: 44, height: 44).accessibilityLabel("Mon compte")
                                        Button { settings = true } label: { Image(systemName: "gearshape").frame(width: 44, height: 44) }.accessibilityLabel("Réglages").accessibilityIdentifier("settings.open")
                                    }
                                }
                            }
                            .toolbarBackground(theme.surface, for: .navigationBar)
                            .toolbarBackground(.visible, for: .navigationBar)
                        }
                        .tabItem { Label(item.rawValue, systemImage: item.icon) }.tag(item)
                    }
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    if network.isOffline { Text("Mode hors connexion — tes données locales restent disponibles").font(.caption).foregroundStyle(theme.muted).padding(8).frame(maxWidth: .infinity).background(theme.background).accessibilityIdentifier("offline.banner") }
                }
                .sheet(isPresented: $settings) { SettingsView() }
            }
        }
        .tint(theme.accent)
        .sheet(isPresented: $store.passwordRecovery) { PasswordRecoveryView() }
        .task { network.onAvailable = { Task { await store.refresh() } }; await store.start() }
        .onChange(of: store.identity?.id) { _, id in if let id { theme.importPreferences(state: store.snapshot.state, userID: id) } }
        .onChange(of: store.snapshot.state) { _, state in if let id = store.identity?.id { theme.importPreferences(state: state, userID: id) } }
        .onAppear { if let id = store.identity?.id { theme.importPreferences(state: store.snapshot.state, userID: id) } }
    }
}
