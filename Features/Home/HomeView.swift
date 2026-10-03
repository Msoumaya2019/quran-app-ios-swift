import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var theme: ThemeManager
    @Binding var tab: MainTab
    @State private var route: HomeRoute?
    @State private var content: DailyContent?
    private var projection: HomeProjection { HomeProjection(snapshot: store.snapshot) }
    private var today: String { projection.today }
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                hero
                readingCard
                SectionHeader(title: "Aujourd’hui", action: "Voir tout") { tab = .program }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    taskCard(title: "Apprentissage", icon: "book", color: theme.accent, passage: store.catalog.reference(projection.learning.flatMap(VerseRange.init(json:))), detail: projection.learning.flatMap(VerseRange.init(json:)).map { "\($0.count) versets" } ?? "Programme à jour") { route = .learning }
                    taskCard(title: "Révision", icon: "arrow.triangle.2.circlepath", color: theme.review, passage: projection.revision.map { store.catalog.reference($0) } ?? "Révisions à jour", detail: projection.revision == nil ? "Aucun passage dû" : "À revoir aujourd’hui") { route = .revision }
                    taskCard(title: "Quiz", icon: "trophy.fill", color: theme.gold, passage: quizStatus, detail: "Teste tes connaissances") { route = .quiz }
                    taskCard(title: "Amis", icon: "person.2.fill", color: theme.review, passage: "Défie tes amis", detail: "Apprenez ensemble") { tab = .friends }
                }
                dailyContents
                SectionHeader(title: "Ma semaine", action: "Voir mes progrès") { tab = .progress }
                weekCard
                Button { route = .objective } label: {
                    AppCard { HStack(spacing: 12) { Image(systemName: "target").foregroundStyle(theme.accent); VStack(alignment: .leading, spacing: 4) { Text("Mon objectif").font(theme.title(.subheadline)); Text(projection.state["goal"]["label"].string ?? "Définir mon programme").font(.caption).foregroundStyle(theme.muted) }; Spacer(); Image(systemName: "chevron.right").font(.caption) } }
                }.buttonStyle(.plain)
                Button { route = .report } label: {
                    AppCard { HStack(spacing: 12) { Image(systemName: "questionmark.circle.fill").foregroundStyle(theme.review).font(.title2); VStack(alignment: .leading, spacing: 5) { Text("Un problème avec l’application ?").font(theme.title(.subheadline)); Text("Signaler une erreur, un bug ou un dysfonctionnement à l’administrateur").font(.caption).foregroundStyle(theme.muted) }; Spacer(); Image(systemName: "chevron.right").font(.caption) } }
                }.buttonStyle(.plain)
                if let message = store.message { Text(message).font(.caption).foregroundStyle(theme.muted).accessibilityIdentifier("sync.notice") }
            }.padding(.horizontal, 18).padding(.bottom, 18)
        }
        .background(theme.background).foregroundStyle(theme.text)
        .refreshable { await store.refresh() }
        .navigationDestination(item: $route) { item in
            if item == .reading { QuranReaderView(initialPage: store.snapshot.state["lastRead"]["page"].int ?? 1, sourceID: store.snapshot.state["reader"]["mushaf"].string) }
            else { PhasePlaceholder(title: item.rawValue) }
        }
        .sheet(item: $content) { value in DailyContentView(content: value) }
        .accessibilityIdentifier("home.screen")
    }
    private var quizStatus: String {
        guard store.snapshot.quizDate == today else { return "Question du jour à synchroniser" }
        if store.snapshot.quizDone { return "Question du jour terminée" }
        return store.snapshot.quizAvailable ? "Question du jour disponible" : "Aucune question aujourd’hui"
    }
    private var hero: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("As-Salâm ‘Alaykoum,").font(.subheadline)
            Text(projection.name).font(theme.title(.largeTitle)).foregroundStyle(theme.accent).accessibilityIdentifier("home.name")
            Text("Prêt à continuer ton apprentissage ?").font(.caption).foregroundStyle(theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 16)
        .background(alignment: .trailing) { Image(theme.hero).resizable().scaledToFill().frame(width: 240, height: 120).opacity(0.5).clipped().allowsHitTesting(false) }
        .clipped()
    }
    private var readingCard: some View {
        let id = projection.readID
        let surah = store.catalog.surah(for: id)
        let ayah = id - (surah?.start ?? 1) + 1
        let page = projection.state["lastRead"]["page"].int ?? store.catalog.page(for: id)
        return AppCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Continuer ma lecture", systemImage: "book").font(theme.title()).foregroundStyle(theme.accent)
                HStack(spacing: 12) {
                    Image("Reading").resizable().scaledToFill().frame(width: 135, height: 142).clipped().clipShape(RoundedRectangle(cornerRadius: 14)).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Sourate").font(.caption).foregroundStyle(theme.muted)
                        Text(surah?.name ?? "Al Fâtiha").font(theme.title(.headline)).foregroundStyle(theme.accent)
                        Text(surah?.arabic ?? "الفاتحة").font(.system(.title3, design: .serif)).foregroundStyle(theme.gold).frame(maxWidth: .infinity, alignment: .trailing)
                        Text("Verset \(ayah) • Page \(page)").font(.caption2).foregroundStyle(theme.muted)
                        ProgressView(value: Double(ayah - 1), total: Double(max(1, surah?.count ?? 7))).tint(theme.accent)
                        Button { route = .reading } label: { Text("Continuer ›") }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("home.continue")
                    }
                }
            }
        }
    }
    private func taskCard(title: String, icon: String, color: Color, passage: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            AppCard {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: icon).font(.body).foregroundStyle(color).frame(width: 30, height: 30).background(color.opacity(0.08), in: Circle())
                    VStack(alignment: .leading, spacing: 5) {
                        Text(title).font(theme.title(.subheadline)).foregroundStyle(color)
                        Text(passage).font(.caption).foregroundStyle(theme.text)
                        Text(detail).font(.caption2).foregroundStyle(theme.muted)
                    }
                    Spacer(minLength: 0)
                }.frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
            }
        }.buttonStyle(.plain).accessibilityIdentifier("home." + title)
    }
    @ViewBuilder private var dailyContents: some View {
        let items = store.snapshot.contentDate == today ? store.snapshot.contents : []
        if !items.isEmpty {
            TabView {
                ForEach(items) { item in
                    Button { content = item } label: {
                        AppCard {
                            HStack(spacing: 10) {
                                AsyncImage(url: item.image_url.flatMap(URL.init(string:))) { image in image.resizable().scaledToFill() } placeholder: { RoundedRectangle(cornerRadius: 12).fill(theme.gold.opacity(0.12)) }
                                    .frame(width: 88, height: 112).clipShape(RoundedRectangle(cornerRadius: 12))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.type == "invocation" ? "Invocation du jour" : "Rappel du jour").font(theme.title(.subheadline)).foregroundStyle(theme.accent)
                                    if let arabic = item.arabic_text { Text(arabic).font(.system(.title3, design: .serif)).frame(maxWidth: .infinity, alignment: .trailing).lineLimit(2) }
                                    if let phonetic = item.phonetic_text { Text(phonetic).font(.caption2).foregroundStyle(theme.muted).lineLimit(1) }
                                    Text(item.french_text).font(.caption).lineLimit(3)
                                    Text([item.source, item.reference].compactMap { $0 }.joined(separator: " • ")).font(.caption2).foregroundStyle(theme.muted).lineLimit(1)
                                }
                                Image(systemName: "chevron.right").font(.caption)
                            }
                        }
                    }.buttonStyle(.plain).padding(.bottom, items.count > 1 ? 22 : 0)
                }
            }.tabViewStyle(.page(indexDisplayMode: items.count > 1 ? .always : .never)).indexViewStyle(.page(backgroundDisplayMode: .always)).frame(height: items.count > 1 ? 176 : 154)
        }
    }
    private var weekCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Versets appris cette semaine").font(.caption).foregroundStyle(theme.muted)
                        Text("\(projection.weeklyVerseCounts.reduce(0, +))").font(theme.title(.title)).foregroundStyle(theme.accent)
                        HStack(alignment: .bottom, spacing: 5) {
                            let maxValue = max(1, projection.weeklyVerseCounts.max() ?? 1)
                            ForEach(0..<7, id: \.self) { day in
                                VStack(spacing: 3) { RoundedRectangle(cornerRadius: 3).fill(theme.accent.opacity(projection.weeklyVerseCounts[day] > 0 ? 1 : 0.12)).frame(height: max(3, Double(projection.weeklyVerseCounts[day]) / Double(maxValue) * 28)); Text(["L", "M", "M", "J", "V", "S", "D"][day]).font(.system(size: 9)) }
                            }
                        }.frame(height: 44).accessibilityLabel("\(projection.weeklyVerseCounts.reduce(0, +)) versets appris cette semaine")
                    }.frame(maxWidth: .infinity)
                    Divider()
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Régularité").font(.caption).foregroundStyle(theme.muted)
                        Text("\(projection.streak) jours d’affilée").font(.subheadline.weight(.semibold))
                        HStack(spacing: 4) { ForEach(0..<7, id: \.self) { i in Circle().fill(i < min(7, projection.streak) ? theme.accent : theme.border).frame(width: 12, height: 12) } }
                    }.frame(maxWidth: .infinity)
                }.fixedSize(horizontal: false, vertical: true)
                Text("Objectif de la semaine : \(Int((projection.week.ratio * 100).rounded())) %").font(.caption).foregroundStyle(theme.muted)
                ProgressView(value: projection.week.ratio).tint(theme.accent)
            }
        }
    }
}
struct DailyContentView: View {
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.dismiss) var dismiss
    let content: DailyContent
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let url = content.image_url.flatMap(URL.init(string:)) { AsyncImage(url: url) { image in image.resizable().scaledToFit() } placeholder: { ProgressView() }.clipShape(RoundedRectangle(cornerRadius: 18)) }
                    if let arabic = content.arabic_text { Text(arabic).font(.title2).frame(maxWidth: .infinity, alignment: .trailing) }
                    if let phonetic = content.phonetic_text { Text(phonetic).foregroundStyle(theme.muted) }
                    Text(content.french_text)
                    if let explanation = content.explanation { Text(explanation) }
                    Text([content.source, content.reference].compactMap { $0 }.joined(separator: " • ")).font(.footnote).foregroundStyle(theme.muted)
                }.padding(20)
            }.background(theme.background).navigationTitle(content.title ?? (content.type == "invocation" ? "Invocation du jour" : "Rappel du jour")).navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() }.frame(minHeight: 44) } }
        }.presentationDragIndicator(.visible)
    }
}
