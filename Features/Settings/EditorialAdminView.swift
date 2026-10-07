import SwiftUI
import UIKit
import PhotosUI
import UniformTypeIdentifiers

struct EditorialAdminView: View {
    @EnvironmentObject var library: EditorialLibrary
    @EnvironmentObject var theme: ThemeManager
    @State private var kind: EditorialKind = .reminder
    @State private var editor: EditorialEditorItem?
    @State private var deletion: JSONValue?
    var body: some View {
        List {
            Picker("Contenu", selection: $kind) { ForEach(EditorialKind.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented).disabled(library.loading)
            NavigationLink("Gérer les catégories") { EditorialCategoriesView(kind: kind) }
            if let message = library.message { Text(message).foregroundStyle(.red) }
            if library.loading { ProgressView("Chargement…") }
            ForEach(library.contents, id: \.selfID) { row in
                VStack(alignment: .leading, spacing: 8) {
                    Button { editor = EditorialEditorItem(draft: EditorialDraft(row: row, kind: kind, categories: library.categories)) } label: {
                        VStack(alignment: .leading) {
                            Text(row["title"].string ?? row["french_text"].string.orEmpty).lineLimit(2).foregroundStyle(theme.text)
                            Text(row["is_active"].bool == true ? "Actif" : "Désactivé").font(.caption).foregroundStyle(theme.muted)
                        }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    ForEach(library.schedules.filter { $0["content_id"] == row["id"] }, id: \.scheduleID) { schedule in
                        HStack { Text(schedule["display_date"].string.orEmpty).font(.caption); Spacer(); Button("Déprogrammer") { Task { await library.unschedule(schedule) } } }
                    }
                    HStack {
                        Button("Dupliquer") {
                            var draft = EditorialDraft(row: row, kind: kind, categories: library.categories)
                            draft.value = draft.value.setting("id", .string(UUID().uuidString.lowercased()))
                            editor = EditorialEditorItem(draft: draft)
                        }
                        Spacer(); Button("Supprimer", role: .destructive) { deletion = row }
                    }.font(.caption).frame(minHeight: 44)
                }
            }
            if library.hasMore { Button("Afficher la suite") { Task { await library.load(kind, more: true) } } }
        }
        .navigationTitle("Rappels et invocations").navigationBarTitleDisplayMode(.inline).tint(theme.accent)
        .toolbar { Button { editor = EditorialEditorItem(draft: EditorialDraft(kind: kind, categories: library.categories)) } label: { Label("Nouveau contenu", systemImage: "plus") }.accessibilityIdentifier("editorial.new") }
        .task(id: kind) { await library.load(kind) }
        .disabled(library.busy)
        .sheet(item: $editor) { item in EditorialEditorView(initial: item.draft) }
        .confirmationDialog("Supprimer ce contenu et ses programmations ?", isPresented: Binding(get: { deletion != nil }, set: { if !$0 { deletion = nil } }), titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) { if let row = deletion { Task { await library.delete(row) } }; deletion = nil }
        }
    }
}

private struct EditorialEditorItem: Identifiable { let id = UUID(); var draft: EditorialDraft }
private struct EditorialEditorView: View {
    @EnvironmentObject var library: EditorialLibrary
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.dismiss) var dismiss
    @State var draft: EditorialDraft
    @State private var scheduled = false
    @State private var day = Date.now
    @State private var photo: PhotosPickerItem?
    @State private var audioImporter = false
    @State private var preparingMedia = false
    @State private var mediaError: String?

    init(initial: EditorialDraft) { _draft = State(initialValue: initial) }
    private var kind: EditorialKind { EditorialKind(rawValue: draft.value["type"].string.orEmpty) ?? .reminder }
    private func text(_ key: String) -> Binding<String> { Binding(get: { draft.value[key].string.orEmpty }, set: { draft.value = draft.value.setting(key, .string($0)) }) }
    var body: some View {
        NavigationStack {
            Form {
                Section("Contenu") {
                    TextField("Titre (facultatif)", text: text("title")).accessibilityIdentifier("editorial.title")
                    Picker("Catégorie", selection: text("category_id")) {
                        Text("Choisir").tag("")
                        ForEach(library.categories.filter { $0["type"].string == kind.rawValue }, id: \.selfID) { row in Text(row["name"].string.orEmpty).tag(row["id"].string.orEmpty) }
                    }
                    TextField("Texte arabe", text: text("arabic_text"), axis: .vertical)
                    TextField("Phonétique", text: text("phonetic_text"), axis: .vertical)
                    TextField("Texte français", text: text("french_text"), axis: .vertical).accessibilityIdentifier("editorial.french")
                    TextField("Explication (facultative)", text: text("explanation"), axis: .vertical)
                    Toggle("Actif", isOn: Binding(get: { draft.value["is_active"].bool ?? true }, set: { draft.value = draft.value.setting("is_active", .bool($0)) }))
                }
                Section("Source") { TextField("Source", text: text("source")).accessibilityIdentifier("editorial.source"); TextField("Référence", text: text("reference")) }
                Section("Médias") {
                    PhotosPicker(selection: $photo, matching: .images) { Label("Choisir une image", systemImage: "photo") }.disabled(preparingMedia || library.busy)
                    if draft.image != nil { Text("Nouvelle image prête · envoi à l’enregistrement").font(.caption); Button("Retirer la sélection d’image") { draft.image = nil; photo = nil } }
                    Button { audioImporter = true } label: { Label("Importer un audio", systemImage: "waveform") }.disabled(preparingMedia || library.busy)
                    if let audio = draft.audio { Text("Audio prêt · \(ByteCountFormatter.string(fromByteCount: Int64(audio.data.count), countStyle: .file))").font(.caption); Button("Retirer la sélection audio") { draft.audio = nil } }
                    if preparingMedia { ProgressView("Préparation du média…") }
                    if let mediaError { Text(mediaError).foregroundStyle(.red) }

                    TextField("Lien HTTPS de l’image", text: text("image_url")).textInputAutocapitalization(.never).keyboardType(.URL)
                    TextField("Lien HTTPS de l’audio", text: text("audio_url")).textInputAutocapitalization(.never).keyboardType(.URL)
                }
                Section("Programmation") {
                    Toggle("Programmer à une date", isOn: $scheduled).accessibilityIdentifier("editorial.scheduled")
                    if scheduled { DatePicker("Date", selection: $day, displayedComponents: .date) }
                    Text("Une publication par type et par jour. Cette date remplace la publication du même type déjà programmée. Les autres dates sont conservées.").font(.caption).foregroundStyle(theme.muted)
                }
                if let message = library.message { Text(message).foregroundStyle(.red) }
                Button(library.busy ? "Enregistrement…" : "Enregistrer") {
                    draft.date = scheduled ? LocalCalendar.key(day) : ""
                    Task { if await library.save(draft) { dismiss(); await store.refresh() } }
                }.disabled(library.busy || library.loading || preparingMedia).accessibilityIdentifier("editorial.save")
            }.navigationTitle(kind == .reminder ? "Rappel" : "Invocation").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Fermer") { dismiss() }.disabled(library.busy || preparingMedia) }
                .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Terminé") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } } }
        }.tint(theme.accent).presentationDragIndicator(.visible)
            .interactiveDismissDisabled(library.busy || preparingMedia)
            .onChange(of: store.identity?.id) { _, _ in dismiss() }
            .task(id: photo) {
                guard let photo, let owner = store.identity?.id else { return }
                preparingMedia = true; mediaError = nil
                defer { preparingMedia = false }
                do {
                    guard let raw = try await photo.loadTransferable(type: Data.self) else { throw CocoaError(.fileReadCorruptFile) }
                    let attachment = try await EditorialAttachment.image(raw)
                    guard !Task.isCancelled, store.identity?.id == owner else { return }
                    draft.image = attachment
                } catch { if !Task.isCancelled, store.identity?.id == owner { mediaError = "L’image n’a pas pu être préparée. Choisis une autre photo." } }
            }
            .fileImporter(isPresented: $audioImporter, allowedContentTypes: [.audio]) { result in
                guard let owner = store.identity?.id else { return }
                switch result {
                case .failure: mediaError = "L’import audio n’a pas abouti."
                case .success(let url): Task {
                    preparingMedia = true; mediaError = nil
                    defer { preparingMedia = false }
                    do {
                        let attachment = try await EditorialAttachment.audio(url)
                        guard store.identity?.id == owner else { return }
                        draft.audio = attachment
                    } catch { if store.identity?.id == owner { mediaError = "Choisis un audio MP3, M4A ou AAC valide, de 30 Mo maximum." } }
                }
                }
            }
    }
}

private struct EditorialCategoriesView: View {
    @EnvironmentObject var library: EditorialLibrary
    let kind: EditorialKind
    @State private var name = ""
    @State private var row: JSONValue = .null
    var body: some View {
        Form {
            Section("Catégories") {
                ForEach(library.categories.filter { $0["type"].string == kind.rawValue }, id: \.selfID) { category in
                    Button(category["name"].string.orEmpty + (category["is_active"].bool == true ? "" : " · Désactivée")) { row = category; name = category["name"].string.orEmpty }
                }
            }
            Section(row == .null ? "Nouvelle catégorie" : "Modifier la catégorie") {
                TextField("Nom", text: $name)
                if row != .null { Toggle("Active", isOn: Binding(get: { row["is_active"].bool ?? true }, set: { row = row.setting("is_active", .bool($0)) })) }
                Button("Enregistrer") {
                    let payload: JSONValue = .object(["id": row["id"].string.map(JSONValue.string) ?? .string(UUID().uuidString.lowercased()), "type": .string(kind.rawValue), "name": .string(name.trimmingCharacters(in: .whitespacesAndNewlines)), "icon": row["icon"].string.map(JSONValue.string) ?? .string("☾"), "display_order": row["display_order"].int.map { .number(Double($0)) } ?? .number(0), "is_active": .bool(row["is_active"].bool ?? true)])
                    Task { if await library.saveCategory(payload) { row = .null; name = "" } }
                }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || library.busy)
                if row != .null { Button("Nouvelle catégorie") { row = .null; name = "" } }
            }
            if let message = library.message { Text(message).foregroundStyle(.red) }
        }.navigationTitle("Catégories")
    }
}

private extension JSONValue {
    var selfID: String { self["id"].string.orEmpty }
    var scheduleID: String { self["type"].string.orEmpty + self["display_date"].string.orEmpty }
}

private extension Optional where Wrapped == String { var orEmpty: String { self ?? "" } }
