import SwiftUI
import UniformTypeIdentifiers

struct RoqyaAdminView: View {
    @EnvironmentObject private var library: RoqyaLibrary
    @EnvironmentObject private var quiz: QuizLibrary
    @EnvironmentObject private var store: AppStore
    private let tables = [("roqyas", "Roqyas"), ("roqya_reciters", "Récitateurs"), ("roqya_audios", "Audios")]
    var body: some View {
        List {
            if quiz.isAdmin {
                ForEach(tables, id: \.0) { table, title in
                    Section(title) {
                        NavigationLink("+ Ajouter") { RoqyaEditor(table: table, row: .null) }
                        ForEach(library.adminRows[table] ?? [], id: \.roqyaID) { row in
                            NavigationLink { RoqyaEditor(table: table, row: row) } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(label(row, table: table))
                                    Text(row["enabled"].bool == true ? "Actif" : "Désactivé").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            } else { Text("Accès réservé à l’administrateur.") }
            if library.adminBusy { ProgressView() }
            if let message = library.message { Text(message).font(.caption) }
        }.navigationTitle("Administration Roqya").navigationBarTitleDisplayMode(.inline)
            .task { library.select(store.identity?.id); await library.refreshAdmin() }.refreshable { await library.refreshAdmin() }
    }
    private func label(_ row: JSONValue, table: String) -> String {
        if table == "roqyas" { return row["title"].string ?? "Roqya" }
        if table == "roqya_reciters" { return row["name"].string ?? "Récitateur" }
        let title = library.adminRows["roqyas"]?.first { $0["id"] == row["roqya_id"] }?["title"].string ?? "Audio"
        let name = library.adminRows["roqya_reciters"]?.first { $0["id"] == row["reciter_id"] }?["name"].string ?? "Récitateur"
        return "\(title) · \(name)"
    }
}

private struct RoqyaEditor: View {
    let table: String
    @EnvironmentObject private var library: RoqyaLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var draft: JSONValue
    @State private var importing = false
    @State private var uploading = false
    @State private var saving = false
    @State private var closed = false
    @State private var importedFiles: [JSONValue] = []
    @State private var error: String?
    init(table: String, row: JSONValue) {
        self.table = table
        _draft = State(initialValue: row == .null ? .object(["enabled": .bool(true), "sort_order": .number(0), "description": .string(""), "category": .string("complete"), "duration_seconds": .number(0)]) : row)
    }
    private func text(_ key: String) -> Binding<String> { Binding(get: { draft[key].string ?? "" }, set: { draft = draft.setting(key, $0.isEmpty ? .null : .string($0)) }) }
    private func number(_ key: String) -> Binding<String> { Binding(get: { draft[key].int.map(String.init) ?? "" }, set: { draft = draft.setting(key, Int($0).map { .number(Double($0)) } ?? .null) }) }
    var body: some View {
        Form {
            Section("Informations") {
                if table == "roqya_audios" {
                    Picker("Roqya", selection: text("roqya_id")) { Text("Choisir").tag(""); ForEach(library.adminRows["roqyas"] ?? [], id: \.roqyaID) { Text($0["title"].string ?? "Roqya").tag($0.roqyaID) } }
                    Picker("Récitateur", selection: text("reciter_id")) { Text("Choisir").tag(""); ForEach(library.adminRows["roqya_reciters"] ?? [], id: \.roqyaID) { Text($0["name"].string ?? "Récitateur").tag($0.roqyaID) } }
                    TextField("Durée en secondes", text: number("duration_seconds")).keyboardType(.numberPad)
                    TextField("Adresse audio HTTPS", text: text("audio_url")).textInputAutocapitalization(.never).keyboardType(.URL)
                    TextField("Chemin du fichier privé", text: text("storage_path")).textInputAutocapitalization(.never)
                } else {
                    TextField(table == "roqyas" ? "Titre" : "Nom", text: text(table == "roqyas" ? "title" : "name"))
                    TextField("Description", text: Binding(get: { draft["description"].string ?? "" }, set: { draft = draft.setting("description", .string($0)) }), axis: .vertical)
                    TextField("Image HTTPS", text: text(table == "roqyas" ? "image_url" : "photo_url")).textInputAutocapitalization(.never).keyboardType(.URL)
                    if table == "roqyas" { TextField("Catégorie", text: text("category")) }
                }
                TextField("Ordre", text: number("sort_order")).keyboardType(.numbersAndPunctuation)
                Toggle("Actif", isOn: Binding(get: { draft["enabled"].bool ?? false }, set: { draft = draft.setting("enabled", .bool($0)) }))
            }
            Section("Fichier") {
                Button(table == "roqya_audios" ? "Importer un audio MP3 / M4A" : "Importer une image") { importing = true }.disabled(uploading)
                if uploading { ProgressView("Envoi du fichier…") }
                Text("Les médias existants sont conservés. Pour retirer un contenu du catalogue, désactive-le.").font(.caption).foregroundStyle(.secondary)
            }
            if let error { Text(error).foregroundStyle(.red).font(.caption) }
            if let message = library.message { Text(message).font(.caption) }
            Button("Enregistrer") {
                Task {
                    saving = true
                    let saved = await library.saveAdmin(table: table, row: draft)
                    saving = false
                    if saved { dismiss(); await library.refreshAdmin(); await library.refresh() }
                    await cleanupIfClosed()
                }
            }.disabled(uploading || saving || library.adminBusy || !RoqyaLibrary.validAdminRow(table: table, row: draft))
        }.navigationTitle("Modifier le catalogue").navigationBarTitleDisplayMode(.inline)
            .onAppear { closed = false }
            .onDisappear { closed = true; Task { await cleanupIfClosed() } }
            .fileImporter(isPresented: $importing, allowedContentTypes: table == "roqya_audios" ? [.audio] : [.image]) { result in
                Task { await upload(result) }
            }
    }
    @MainActor private func cleanupIfClosed() async {
        guard closed, !uploading, !saving else { return }
        let files = importedFiles
        importedFiles = []
        for file in files { await library.discardAdminUpload(file) }
    }
    @MainActor private func upload(_ result: Result<URL, Error>) async {
        do {
            let file = try result.get(), access = file.startAccessingSecurityScopedResource()
            defer { if access { file.stopAccessingSecurityScopedResource() } }
            uploading = true; defer { uploading = false; Task { await cleanupIfClosed() } }
            let value = try await library.uploadAdmin(file: file, audio: table == "roqya_audios")
            importedFiles.append(value)
            if table == "roqya_audios" { draft = draft.setting("storage_path", value["storage_path"]).setting("file_size", value["file_size"]).setting("audio_url", .null) }
            else { draft = draft.setting(table == "roqyas" ? "image_url" : "photo_url", value["url"]) }
            error = nil
        } catch { self.error = "Envoi impossible. Vérifie le format, la taille et les droits du compte." }
    }
}
