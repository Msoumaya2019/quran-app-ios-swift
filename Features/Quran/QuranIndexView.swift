import SwiftUI

struct QuranIndexView: View {
    enum Section: String, CaseIterable { case list = "Liste", juz = "Juz’", hizb = "Hizb" }
    let source: QuranSource
    let open: (Int) -> Void
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @State private var section = Section.list
    @State private var search = ""
    private var catalog: QuranCatalog { store.catalog }
    private func matches(_ value: String) -> Bool {
        search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || value.localizedStandardContains(search.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    var body: some View {
        List {
            SwiftUI.Section {
                Button {
                    open(source.validPage(store.snapshot.state["lastRead"]["sourcePages"][source.id].int ?? store.snapshot.state["lastRead"]["page"].int ?? 1))
                } label: { Label("Reprendre ma lecture", systemImage: "bookmark").foregroundStyle(theme.accent).frame(minHeight: 44) }
                Picker("Parcourir le Coran", selection: $section) {
                    ForEach(Section.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).accessibilityIdentifier("quran.index.sections")
            }
            if section == .list {
                ForEach(catalog.surahs.filter { matches("\($0.number) \($0.name) \($0.meaning) \($0.arabic)") }, id: \.number) { surah in
                    Button { open(QuranSourceMapping.page(source: source, verseID: surah.start, catalog: catalog)) } label: {
                        HStack(spacing: 12) {
                            QuranNumberMedallion(number: surah.number)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(surah.name).font(theme.title(.subheadline)).foregroundStyle(theme.text)
                                Text(surah.meaning).font(.caption).foregroundStyle(theme.muted)
                                Text("\(surah.isMeccan ? "Mecquoise" : "Médinoise") · \(surah.count) versets").font(.caption2).foregroundStyle(theme.muted)
                            }
                            Spacer(minLength: 4)
                            Text(surah.arabic).font(.system(size: 20)).foregroundStyle(theme.accent).minimumScaleFactor(0.8)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(theme.muted)
                        }.padding(.vertical, 3)
                    }.accessibilityIdentifier("quran.index.surah.\(surah.number)")
                }.listRowBackground(theme.surface)
            } else {
                ForEach((section == .juz ? catalog.juzs : catalog.hizbs).filter { matches("\(section.rawValue) \($0.number)") }) { division in
                    Button { open(QuranSourceMapping.page(source: source, verseID: division.start, catalog: catalog)) } label: {
                        HStack(spacing: 12) {
                            QuranNumberMedallion(number: division.number)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(section.rawValue) \(division.number)").font(theme.title(.subheadline)).foregroundStyle(theme.text)
                                Text("Pages \(QuranSourceMapping.page(source: source, verseID: division.start, catalog: catalog))–\(QuranSourceMapping.page(source: source, verseID: division.end, catalog: catalog))").font(.caption).foregroundStyle(theme.muted)
                            }
                            Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(theme.muted)
                        }.padding(.vertical, 4)
                    }.accessibilityIdentifier("quran.index.\(section == .juz ? "juz" : "hizb").\(division.number)")
                }.listRowBackground(theme.surface)
            }
        }
        .scrollContentBackground(.hidden).background(theme.background)
        .searchable(text: $search, prompt: section == .list ? "Rechercher une sourate" : "Rechercher un \(section.rawValue)")
        .navigationTitle("Le Coran").navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { Text(source.displayName + " · 604 pages").font(.caption).foregroundStyle(theme.muted).padding(8).frame(maxWidth: .infinity).background(theme.background) }
    }
}

struct QuranNumberMedallion: View {
    let number: Int
    @EnvironmentObject private var theme: ThemeManager
    var body: some View {
        ZStack {
            MedallionShape().stroke(theme.gold, lineWidth: 1.2)
            MedallionShape().inset(by: 3).stroke(theme.gold.opacity(0.55), lineWidth: 0.6)
            Text(String(number)).font(.system(size: 15, weight: .medium, design: .serif)).foregroundStyle(theme.text)
        }.frame(width: 42, height: 42).accessibilityHidden(true)
    }
}
private struct MedallionShape: InsettableShape {
    var insetAmount: CGFloat = 0
    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        for i in 0..<16 {
            let angle = Double(i) * Double.pi / 8 - Double.pi / 2
            let r = radius * (i % 2 == 0 ? 1 : 0.8)
            let point = CGPoint(x: rect.midX + CGFloat(cos(angle)) * r, y: rect.midY + CGFloat(sin(angle)) * r)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath(); return path
    }
    func inset(by amount: CGFloat) -> some InsettableShape { var copy = self; copy.insetAmount += amount; return copy }
}
