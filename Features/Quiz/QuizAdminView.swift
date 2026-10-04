import SwiftUI

struct QuizAdminView: View {
    @EnvironmentObject var quiz: QuizLibrary
    @State private var deleteID = ""
    @State private var deleteSet = false
    @State private var confirmDelete = false
    var body: some View {
        List {
            if quiz.isAdmin {
                Section("Questions") {
                    NavigationLink("+ Nouvelle question") { QuizQuestionEditor(question: .null) }
                    ForEach(quiz.adminQuestions, id: \.adminID) { row in
                        NavigationLink { QuizQuestionEditor(question: row) } label: {
                            VStack(alignment: .leading, spacing: 5) { Text(row["question"].string ?? "Question"); Text("\(row["category"].string ?? "") · \(row["publicationDate"].string ?? "Sans date")\(row["isActive"].bool == false ? " · Inactive" : "")").font(.caption) }
                        }.swipeActions { Button("Supprimer", role: .destructive) { deleteID = row.adminID; deleteSet = false; confirmDelete = true } }
                    }
                }
                Section("Quiz thématiques · 10 questions") {
                    NavigationLink("+ Nouveau quiz de 10 questions") { QuizSetEditor(value: .null) }
                    ForEach(quiz.adminSets, id: \.adminID) { row in
                        NavigationLink(row["title"].string ?? "Quiz") { QuizSetEditor(value: row) }
                            .swipeActions { Button("Supprimer", role: .destructive) { deleteID = row.adminID; deleteSet = true; confirmDelete = true } }
                    }
                }
            } else { Text("Accès réservé à l’administrateur connecté.") }
            if let message = quiz.message { Text(message).font(.caption) }
        }.navigationTitle("Administration Quiz")
            .task { await quiz.checkAdmin(); await quiz.refreshAdmin() }
            .refreshable { await quiz.refreshAdmin() }
            .confirmationDialog("Supprimer cet élément ?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Supprimer", role: .destructive) { Task { await quiz.adminDelete(deleteID, isSet: deleteSet) } }
            }
    }
}

struct QuizQuestionEditor: View {
    @EnvironmentObject var quiz: QuizLibrary
    @Environment(\.dismiss) var dismiss
    @State private var draft: JSONValue
    @State private var answers: [JSONValue]
    private let isNew: Bool
    private let categories = ["Coran", "Tajwid", "Prophètes", "Sîra", "Vocabulaire coranique", "Connaissances générales"]
    init(question: JSONValue) {
        isNew = question == .null
        _draft = State(initialValue: question == .null ? .object(["id": .string(UUID().uuidString), "category": .string("Coran"), "isActive": .bool(true), "isDailyQuestion": .bool(false), "availableForChallenges": .bool(true), "correctAnswerId": .string("A")]) : question)
        let existing = question["answers"].array
        _answers = State(initialValue: (0..<4).map { index in index < existing.count ? existing[index] : .object(["id": .string(existing.isEmpty ? String(UnicodeScalar(65 + index)!) : UUID().uuidString), "text": .string("")]) })
    }
    private func text(_ key: String) -> Binding<String> { Binding(get: { draft[key].string ?? "" }, set: { draft = draft.setting(key, .string($0)) }) }
    private func flag(_ key: String) -> Binding<Bool> { Binding(get: { draft[key].bool ?? false }, set: { draft = draft.setting(key, .bool($0)) }) }
    private func number(_ key: String) -> Binding<String> { Binding(get: { draft[key].string ?? draft[key].int.map(String.init) ?? "" }, set: { draft = draft.setting(key, .string($0)) }) }
    private var valid: Bool {
        !draft["question"].string.orEmpty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !draft["sourceTitle"].string.orEmpty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (draft["sourceUrl"].string.orEmpty.isEmpty || draft["sourceUrl"].string.orEmpty.hasPrefix("https://")) && (draft["isDailyQuestion"].bool != true || !draft["publicationDate"].string.orEmpty.isEmpty) && answers.filter { !$0["text"].string.orEmpty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count >= 3 && answers.contains { $0["id"].string == draft["correctAnswerId"].string && !$0["text"].string.orEmpty.isEmpty }
    }
    var body: some View {
        Form {
            Section("Question") {
                Picker("Catégorie", selection: text("category")) { ForEach(categories, id: \.self) { Text($0).tag($0) } }
                TextField("Question", text: text("question"), axis: .vertical).lineLimit(3...8)
                ForEach(answers.indices, id: \.self) { index in
                    TextField("Réponse \(index + 1)", text: Binding(get: { answers[index]["text"].string ?? "" }, set: { answers[index] = answers[index].setting("text", .string($0)) }))
                }
                Picker("Bonne réponse", selection: text("correctAnswerId")) { ForEach(answers, id: \.adminID) { row in Text(row["text"].string.orEmpty.isEmpty ? "Réponse " + row.adminID : row["text"].string.orEmpty).tag(row.adminID) } }
            }
            Section("Correction et source") {
                TextField("Explication", text: text("explanation"), axis: .vertical).lineLimit(3...8)
                TextField("Texte arabe facultatif", text: text("arabic"), axis: .vertical)
                TextField("Traduction", text: text("translation"), axis: .vertical)
                TextField("Source", text: text("sourceTitle"))
                TextField("Référence", text: text("sourceReference"))
                TextField("Lien source", text: text("sourceUrl")).textInputAutocapitalization(.never).keyboardType(.URL)
                TextField("Sourate facultative", text: number("surah")).keyboardType(.numberPad)
                TextField("Verset facultatif", text: number("ayah")).keyboardType(.numberPad)
            }
            Section("Publication") {
                Toggle("Question du jour", isOn: flag("isDailyQuestion"))
                TextField("Date · AAAA-MM-JJ", text: text("publicationDate")).keyboardType(.numbersAndPunctuation)
                Toggle("Disponible pour les défis", isOn: flag("availableForChallenges"))
                Toggle("Active", isOn: flag("isActive"))
            }
            if let message = quiz.message { Text(message).font(.caption) }
            Button("Enregistrer") {
                let value = draft.setting("answers", .array(answers.filter { !$0["text"].string.orEmpty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }))
                Task { if await quiz.adminSave(value) { dismiss() } }
            }.disabled(!valid || quiz.actionBusy)
            if !isNew {
                NavigationLink("Dupliquer") { QuizQuestionEditor(question: draft.setting("id", .string(UUID().uuidString)).setting("publicationDate", .null).setting("isDailyQuestion", .bool(false)).setting("answers", .array(answers))) }
            }
        }.navigationTitle(isNew ? "Nouvelle question" : "Modifier la question").navigationBarTitleDisplayMode(.inline)
    }
}

struct QuizSetEditor: View {
    @EnvironmentObject var quiz: QuizLibrary
    @Environment(\.dismiss) var dismiss
    @State private var draft: JSONValue
    @State private var selected: Set<String>
    init(value: JSONValue) {
        _draft = State(initialValue: value == .null ? .object(["id": .string(UUID().uuidString), "isActive": .bool(true), "category": .string("Coran")]) : value)
        _selected = State(initialValue: Set(value["questionIds"].array.compactMap(\.string)))
    }
    private func text(_ key: String) -> Binding<String> { Binding(get: { draft[key].string ?? "" }, set: { draft = draft.setting(key, .string($0)) }) }
    var body: some View {
        Form {
            TextField("Titre du quiz", text: text("title"))
            TextField("Thème", text: text("category"))
            Toggle("Actif", isOn: Binding(get: { draft["isActive"].bool ?? true }, set: { draft = draft.setting("isActive", .bool($0)) }))
            Section("\(selected.count) / 10 questions") {
                ForEach(quiz.adminQuestions.filter { $0["isActive"].bool == true && $0["availableForChallenges"].bool == true }, id: \.adminID) { row in
                    Button { if selected.contains(row.adminID) { selected.remove(row.adminID) } else if selected.count < 10 { selected.insert(row.adminID) } } label: { HStack { Text(row["question"].string ?? "Question"); Spacer(); Image(systemName: selected.contains(row.adminID) ? "checkmark.circle.fill" : "circle") } }.buttonStyle(.plain)
                }
            }
            if let message = quiz.message { Text(message).font(.caption) }
            Button("Enregistrer le quiz") {
                let value = draft.setting("questionIds", .array(selected.sorted().map(JSONValue.string)))
                Task { if await quiz.adminSave(value, isSet: true) { dismiss() } }
            }.disabled(selected.count != 10 || draft["title"].string.orEmpty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || quiz.actionBusy)
        }.navigationTitle("Quiz de 10 questions").navigationBarTitleDisplayMode(.inline)
    }
}
private extension JSONValue { var adminID: String { self["id"].string ?? "" } }
private extension Optional where Wrapped == String { var orEmpty: String { self ?? "" } }
