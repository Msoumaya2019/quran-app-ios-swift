import SwiftUI

struct NativeProgressView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var quiz: QuizLibrary
    @EnvironmentObject var theme: ThemeManager
    var body: some View {
        let progress = ProgressProjection(state: store.snapshot.state)
        let home = HomeProjection(snapshot: store.snapshot)
        let statistics = QuizStatistics(data: quiz.cache?.data ?? .null, owner: quiz.cache?.owner)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Ma progression").font(theme.title(.title)).foregroundStyle(theme.accent)
                Text("Suis ton évolution pas à pas.").font(.subheadline).foregroundStyle(theme.muted)
                AppCard {
                    HStack(spacing: 18) {
                        ZStack {
                            Circle().stroke(theme.accent.opacity(0.1), lineWidth: 10)
                            Circle().trim(from: 0, to: Double(progress.known.count) / 6236).stroke(theme.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round)).rotationEffect(.degrees(-90))
                            Text("\(Int(Double(progress.known.count) / 6236 * 100)) %").font(theme.title(.title2))
                        }.frame(width: 92, height: 92)
                        VStack(alignment: .leading, spacing: 6) { Text("\(progress.known.count) / 6236").font(theme.title(.title2)); Text("versets mémorisés").font(.subheadline).foregroundStyle(theme.muted) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    stat("Versets appris cette semaine", value: home.weeklyVerseCounts.reduce(0, +), icon: "chart.bar")
                    stat("Jours d’affilée", value: home.streak, icon: "calendar")
                    stat("Pages mémorisées", value: progress.completePages(catalog: store.catalog), icon: "book")
                    stat("Passages révisés", value: store.snapshot.state["reviewHistory"].array.count, icon: "arrow.triangle.2.circlepath")
                    stat("Juz’ complétés", value: progress.completeJuzs(catalog: store.catalog), icon: "book.closed")
                }
                Text("Mon objectif").font(theme.title()).foregroundStyle(theme.accent)
                AppCard { VStack(alignment: .leading, spacing: 10) { Text(store.snapshot.state["goal"]["label"].string ?? "Aucun objectif défini").font(theme.title()); HStack { ProgressView(value: progress.goalRatio).tint(theme.accent); Text("\(Int(progress.goalRatio * 100)) %").font(.caption) } } }
                Text("Quiz").font(theme.title()).foregroundStyle(theme.accent)
                AppCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Questions du jour : \(statistics.dailyCorrect) bonnes réponses / \(statistics.dailyTotal)")
                        Text("Taux de réussite : \(statistics.successPercent) %")
                        Text("Défis terminés : \(statistics.completed.count)")
                        Text("Victoires : \(statistics.wins) · Égalités : \(statistics.draws)")
                        NavigationLink("Ouvrir le Quiz") { QuizView() }.frame(minHeight: 44)
                    }.font(.subheadline)
                }
            }.padding(18)
        }.background(theme.background).foregroundStyle(theme.text).accessibilityIdentifier("progress.screen")
            .task { await quiz.refresh() }.refreshable { await store.refresh(); await quiz.refresh() }
    }
    private func stat(_ title: String, value: Int, icon: String) -> some View {
        AppCard { VStack(alignment: .leading, spacing: 8) { Label(title, systemImage: icon).font(.caption).foregroundStyle(theme.muted); Text(String(value)).font(theme.title(.title2)).foregroundStyle(theme.accent) }.frame(maxWidth: .infinity, minHeight: 72, alignment: .leading) }
    }
}
