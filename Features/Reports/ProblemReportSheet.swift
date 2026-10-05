import SwiftUI
import PhotosUI

struct ProblemReportSheet: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var reports: ProblemReportLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var type = ProblemType.bug
    @State private var description = ""
    @State private var photo: PhotosPickerItem?
    @State private var screenshot: Data?
    @State private var preparing = false
    @State private var photoRequest = UUID()
    @State private var saved = false
    @State private var error: String?
    private var count: Int { description.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars.count }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Envoyez un signalement à l’administrateur").font(.subheadline).foregroundStyle(theme.muted)
                    if saved {
                        Label(reports.notice ?? "Signalement enregistré.", systemImage: "checkmark.circle.fill").foregroundStyle(theme.review).accessibilityIdentifier("report.saved")
                        Button("Fermer") { dismiss() }.buttonStyle(PrimaryButtonStyle())
                    } else {
                        Text("Type de problème").font(theme.title(.subheadline))
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 115))], spacing: 8) {
                            ForEach(ProblemType.allCases) { value in
                                Button { type = value } label: {
                                    Label(value.rawValue, systemImage: value.icon).font(.subheadline).frame(maxWidth: .infinity, minHeight: 44)
                                        .foregroundStyle(type == value ? theme.review : theme.text)
                                        .background(type == value ? theme.review.opacity(0.08) : theme.surface, in: RoundedRectangle(cornerRadius: 14))
                                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(type == value ? theme.review : theme.border))
                                }.buttonStyle(.plain).accessibilityIdentifier("report.type." + value.rawValue)
                            }
                        }
                        Text("Décrivez le problème").font(theme.title(.subheadline))
                        VStack(alignment: .trailing, spacing: 5) {
                            TextEditor(text: $description).frame(height: 125).scrollContentBackground(.hidden).accessibilityIdentifier("report.description")
                            Text("\(description.unicodeScalars.count)/500").font(.caption).foregroundStyle(count > 500 ? .red : theme.muted)
                        }.padding(10).background(theme.surface, in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.border))
                        PhotosPicker(selection: $photo, matching: .images) {
                            AppCard { HStack { Image(systemName: "photo").foregroundStyle(theme.review); VStack(alignment: .leading, spacing: 4) { Text(screenshot == nil ? "Ajouter une capture" : "Changer la capture").font(.subheadline); Text("Photo ou capture d’écran (optionnel)").font(.caption).foregroundStyle(theme.muted) }; Spacer(); if preparing { ProgressView() } else { Image(systemName: "chevron.right") } }.frame(minHeight: 44) }
                        }.buttonStyle(.plain).disabled(preparing).accessibilityIdentifier("report.photo")
                        if let screenshot, let image = UIImage(data: screenshot) {
                            HStack { Image(uiImage: image).resizable().scaledToFit().frame(height: 100); Spacer(); Button("Retirer", role: .destructive) { self.screenshot = nil; photo = nil }.frame(minHeight: 44) }
                        }
                        if let error { Text(error).font(.caption).foregroundStyle(.red) }
                        Button("Envoyer à l’administrateur") {
                            do {
                                try reports.enqueue(type: type, description: description, screenshot: screenshot, version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0")
                                saved = true; Task { await reports.synchronize() }
                            } catch { self.error = "Le signalement n’a pas pu être enregistré. Vérifie la description et l’espace disponible." }
                        }.buttonStyle(PrimaryButtonStyle()).disabled(count == 0 || count > 500 || preparing || reports.owner == nil).accessibilityIdentifier("report.send")
                    }
                }.padding(20)
            }.scrollDismissesKeyboard(.interactively).background(theme.background).foregroundStyle(theme.text)
                .navigationTitle("Signaler un problème").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }.accessibilityLabel("Fermer") } }
        }.presentationDetents([.large]).presentationDragIndicator(.visible).presentationCornerRadius(28)
            .onChange(of: photo) { _, selected in
                let request = UUID(); photoRequest = request
                guard let selected else { preparing = false; return }
                preparing = true; error = nil
                Task {
                    do {
                        guard let bytes = try await selected.loadTransferable(type: Data.self) else { throw CocoaError(.fileReadCorruptFile) }
                        let result = try await ProblemScreenshot.prepare(bytes)
                        guard photoRequest == request else { return }; screenshot = result
                    } catch { if photoRequest == request { self.error = "Cette image n’a pas pu être ajoutée." } }
                    if photoRequest == request { preparing = false }
                }
            }
    }
}
