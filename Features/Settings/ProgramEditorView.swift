import SwiftUI

struct ProgramEditorView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @State private var goalMode = "current"
    @State private var goalNumber = 1
    @State private var pace: String
    @State private var days: Set<Int>
    @State private var direction: String
    @State private var dated: Bool
    @State private var deadline: Date
    @State private var message: String?
    @State private var lastSavedConfiguration: JSONValue?
    init(state: JSONValue) {
        _pace = State(initialValue: state["pace"].string ?? "verse3")
        _days = State(initialValue: Set(state["learningDays"] == .null ? [1, 2, 3, 4, 5] : state["learningDays"].array.compactMap(\.int)))
        _direction = State(initialValue: state["goal"]["direction"].string ?? "fromStart")
        _dated = State(initialValue: state["goal"]["deadline"].string != nil)
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"; formatter.locale = Locale(identifier: "en_US_POSIX")
        _deadline = State(initialValue: state["goal"]["deadline"].string.flatMap(formatter.date(from:)) ?? .now)
    }
    private var goal: JSONValue {
        var result = store.snapshot.state["goal"]
        let end: Int?, label: String
        switch goalMode {
        case "surah": let surah = store.catalog.surahs.first { $0.number == goalNumber }; end = surah?.end; label = "Finir \(surah?.name ?? "la sourate")"
        case "hizb": end = store.catalog.hizbs.first { $0.number == goalNumber }?.end; label = "Finir le Hizb \(goalNumber)"
        case "juz": end = store.catalog.juzs.first { $0.number == goalNumber }?.end; label = "Finir le Juz’ \(goalNumber)"
        case "all": end = 6236; label = "Tout le Coran"
        default: end = nil; label = result["label"].string ?? "Mon objectif"
        }
        if let end { result = result.setting("label", .string(label)).setting("ranges", .array([.object(["start": .number(1), "end": .number(Double(end))])])) }
        return result.setting("direction", .string(direction)).setting("deadline", dated ? .string(LocalCalendar.key(deadline)) : .null)
    }
    private var valid: Bool { !days.isEmpty && !goal["ranges"].array.isEmpty && ProgramEdit.paces.contains { $0.0 == pace } }
    var body: some View {
        ScrollViewReader { scroll in
        Form {
            Section {
                if let message { Text(message).accessibilityIdentifier("program.editor.result") }
                else { Text("Ajuste ton objectif et ton rythme. Tes connaissances restent intactes.").font(.caption) }
            }.id("program.editor.top")
            Section("Mon objectif") {
                Text(store.snapshot.state["goal"]["label"].string ?? "Définir un objectif").font(.subheadline).foregroundStyle(theme.muted)
                Picker("Objectif", selection: $goalMode) {
                    Text("Conserver l’objectif actuel").tag("current"); Text("Finir une sourate").tag("surah")
                    Text("Finir un Hizb").tag("hizb"); Text("Finir un Juz’").tag("juz"); Text("Tout le Coran").tag("all")
                }.accessibilityIdentifier("program.editor.goal")
                if goalMode == "surah" {
                    Picker("Dernière sourate", selection: $goalNumber) { ForEach(store.catalog.surahs, id: \.number) { Text($0.name).tag($0.number) } }
                } else if goalMode == "hizb" || goalMode == "juz" {
                    Picker(goalMode == "hizb" ? "Dernier Hizb" : "Dernier Juz’", selection: $goalNumber) {
                        ForEach(1...(goalMode == "hizb" ? 60 : 30), id: \.self) { Text(String($0)).tag($0) }
                    }
                }
                Picker("Sens d’apprentissage", selection: $direction) { Text("Depuis le début").tag("fromStart"); Text("Depuis An-Nâs").tag("fromNas") }
                Toggle("Choisir une échéance", isOn: $dated)
                if dated { DatePicker("Échéance", selection: $deadline, displayedComponents: .date) }
                Text("Les objectifs par sourate, Hizb ou Juz’ couvrent le début du Coran jusqu’à la limite choisie. Tes connaissances actuelles sont conservées.").font(.caption)
            }
            Section("Mon rythme") {
                Picker("Quantité par séance", selection: $pace) {
                    ForEach(ProgramEdit.paces.map { $0.0 }, id: \.self) { value in Text(ProgramEdit.paces.first { $0.0 == value }?.1 ?? value).tag(value) }
                    if !ProgramEdit.paces.contains(where: { $0.0 == pace }) { Text("Rythme actuel · \(pace)").tag(pace) }
                }.accessibilityIdentifier("program.editor.pace")
            }
            Section("Jours d’apprentissage") {
                ForEach(Array(["Dimanche", "Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi"].enumerated()), id: \.offset) { day in
                    Toggle(day.element, isOn: Binding(get: { days.contains(day.offset) }, set: { value in if value { days.insert(day.offset) } else { days.remove(day.offset) } }))
                }
                if days.isEmpty { Text("Choisis au moins un jour.").font(.caption).foregroundStyle(.red) }
            }
            Section("Programme") {
                Text("Les séances non commencées seront recalculées à partir d’aujourd’hui. Les séances terminées ou commencées, leurs dates et ton historique seront conservés.").font(.caption)
                Button("Enregistrer mon programme") { save() }.disabled(!valid || lastSavedConfiguration == configuration).frame(minHeight: 44)
                    .accessibilityIdentifier("program.editor.save")
            }
        }.navigationTitle("Modifier mon programme").navigationBarTitleDisplayMode(.inline).tint(theme.accent)
            .onChange(of: message) { _, _ in withAnimation(.easeOut(duration: 0.18)) { scroll.scrollTo("program.editor.top", anchor: .top) } }
            .onChange(of: goalMode) { _, _ in goalNumber = 1 }
        }
    }
    private var configuration: JSONValue {
        .object(["goal": goal, "pace": .string(pace), "days": .array(days.sorted().map { .number(Double($0)) })])
    }
    private func save() {
        let edit = ProgramEdit(goal: goal, pace: pace, days: Array(days))
        var operation = ReaderOperation(kind: .program, verseID: 1, page: 1, source: "traditional")
        operation.program = edit
        if store.readerChange(operation) {
            lastSavedConfiguration = configuration
            message = "Programme enregistré. Tes séances commencées et ton historique sont conservés."
            Task { await store.refresh() }
        } else { message = "Ce programme n’a pas pu être enregistré. Vérifie l’objectif, le rythme et les jours choisis." }
    }
}
