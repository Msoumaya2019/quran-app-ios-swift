import SwiftUI

struct ProgramView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @State private var selected: QuranSessionContext?
    private var projection: ProgramProjection { ProgramProjection(snapshot: store.snapshot) }
    private var reviewTasks: [QuranSessionContext] { ReviewQueueProjection(program: projection).tasks }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Mon programme").font(theme.title(.title)).foregroundStyle(theme.accent)
                Text("Ton parcours du jour, calculé selon ton objectif").font(.subheadline).foregroundStyle(theme.muted)
                AppCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Aujourd’hui", systemImage: "calendar").font(theme.title()).foregroundStyle(theme.accent)
                        Text(projection.today).font(.caption).foregroundStyle(theme.muted)
                        Text(RevisionPreferences(state: store.snapshot.state).title).font(.caption).foregroundStyle(theme.review)
                        if let task = projection.todayLearning { row(task) }
                        else { Text("Aucune séance d’apprentissage prévue aujourd’hui").font(.subheadline).foregroundStyle(theme.muted) }
                        if let task = reviewTasks.first { row(task) }
                    }
                }
                let week = HomeProjection(snapshot: store.snapshot).week
                AppCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text("Objectif de la semaine").font(theme.title(.subheadline)); Spacer(); Text("\(Int(week.ratio * 100)) %").font(.subheadline.weight(.semibold)) }
                        ProgressView(value: week.ratio).tint(theme.accent)
                        Text("\(week.done) / \(week.total) séances terminées").font(.caption).foregroundStyle(theme.muted)
                    }
                }
                if !projection.overdue.isEmpty {
                    Text("Séances à reprendre").font(theme.title()).foregroundStyle(theme.accent)
                    ForEach(projection.overdue) { task in AppCard { row(task) } }
                }
                let recent = reviewTasks.filter { $0.revisionCategory == "recent" }
                let priority = reviewTasks.filter { $0.revisionCategory == "priority" }
                if !recent.isEmpty {
                    Text("Révisions récentes").font(theme.title()).foregroundStyle(theme.review)
                    ForEach(recent) { task in AppCard { row(task) } }
                }
                if !priority.isEmpty {
                    Text("Révisions prioritaires").font(theme.title()).foregroundStyle(theme.review)
                    Text("Tes versets difficiles à revoir").font(.caption).foregroundStyle(theme.muted)
                    ForEach(priority) { task in AppCard { row(task) } }
                }
                if !projection.consolidations.isEmpty {
                    Text("Nouveaux versets à consolider").font(theme.title()).foregroundStyle(theme.accent)
                    ForEach(projection.consolidations) { task in AppCard { row(task) } }
                }
                Text("À venir").font(theme.title()).foregroundStyle(theme.accent)
                if projection.upcoming.isEmpty { Text("Aucune séance prévue dans les dix prochains jours").font(.subheadline).foregroundStyle(theme.muted) }
                ForEach(projection.upcoming) { task in AppCard { row(task) } }
            }.padding(18)
        }.background(theme.background).foregroundStyle(theme.text)
            .refreshable { await store.refresh() }
            .navigationDestination(item: $selected) { task in
                QuranReaderView(sourceID: store.snapshot.state["reader"]["mushaf"].string, mode: task.mode, session: task)
            }
            .accessibilityIdentifier("program.screen")
    }
    private func row(_ task: QuranSessionContext) -> some View {
        Button { selected = task } label: {
            HStack(spacing: 12) {
                Image(systemName: task.mode == .learning ? "book" : "arrow.triangle.2.circlepath").foregroundStyle(task.mode == .learning ? theme.accent : theme.review).frame(width: 32)
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title).font(.caption.weight(.semibold)).foregroundStyle(theme.accent)
                    Text(store.catalog.reference(task.range)).font(.subheadline.weight(.semibold)).foregroundStyle(theme.text)
                    Text("\(projection.dateLabel(task.scheduledDate)) · \(task.range.count) versets").font(.caption).foregroundStyle(theme.muted)
                }
                Spacer(minLength: 4); Image(systemName: "chevron.right").font(.caption).foregroundStyle(theme.muted)
            }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier("program.task.\(task.id)")
    }
}
