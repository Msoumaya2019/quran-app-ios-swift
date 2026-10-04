import SwiftUI

struct FriendDetailView: View {
    let item: FriendItem
    @EnvironmentObject var library: FriendsLibrary
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var network: ConnectivityService
    @State private var message: String?
    var body: some View {
        let overview = library.snapshot?.overview(for: item.otherID) ?? .null
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AppCard {
                    HStack(spacing: 14) {
                        Text(String(item.name.prefix(1))).font(.title2).foregroundStyle(theme.accent).frame(width: 56, height: 56).background(theme.accent.opacity(0.08), in: Circle())
                        VStack(alignment: .leading, spacing: 5) {
                            Text(item.name).font(theme.title())
                            Text("Apprenez et progressez ensemble").font(.caption).foregroundStyle(theme.muted)
                        }
                    }
                }
                if overview != .null {
                    AppCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Cette semaine").font(theme.title())
                            Text("\(max(0, overview["weekly_verses"].int ?? 0)) versets · \(max(0, overview["weekly_sessions"].int ?? 0)) séances").font(.subheadline)
                            Text("Coran mémorisé : \(percentage(overview["quran_percent"])) %").font(.subheadline)
                            ProgressView(value: Double(percentage(overview["quran_percent"])), total: 100).tint(theme.accent)
                        }
                    }.accessibilityIdentifier("friends.detail.progress")
                    if let goal = overview["goal_label"].string, !goal.isEmpty {
                        AppCard { VStack(alignment: .leading, spacing: 10) { Text("Son objectif").font(theme.title()); Text(goal).font(.subheadline); ProgressView(value: Double(percentage(overview["goal_percent"])), total: 100).tint(theme.accent); Text("\(percentage(overview["goal_percent"])) %").font(.caption).foregroundStyle(theme.muted) } }
                    }
                    if let date = overview["updated_at"].string {
                        Text("Dernière synchronisation : \(formatted(date))").font(.caption).foregroundStyle(theme.muted)
                    }
                } else {
                    Text("La progression n’est pas partagée ou n’a pas encore été synchronisée.").font(.subheadline).foregroundStyle(theme.muted)
                }
                if let message { Text(message).font(.caption).foregroundStyle(theme.muted) }
            }.padding(16)
        }.background(theme.background).navigationTitle(item.name).navigationBarTitleDisplayMode(.inline)
            .task { if !network.isOffline { await library.refresh(); message = await library.refreshOverview(item.otherID) } }
            .refreshable { if !network.isOffline { message = await library.refreshOverview(item.otherID) } }
    }
    private func percentage(_ value: JSONValue) -> Int { min(100, max(0, value.int ?? 0)) }
    private func formatted(_ raw: String) -> String {
        let parser = ISO8601DateFormatter(); parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = parser.date(from: raw) ?? ISO8601DateFormatter().date(from: raw) else { return "date indisponible" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
