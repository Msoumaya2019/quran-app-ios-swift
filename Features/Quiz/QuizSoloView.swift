import SwiftUI

struct QuizSoloView: View {
    @EnvironmentObject var quiz: QuizLibrary
    @EnvironmentObject var theme: ThemeManager
    @State private var index = 0
    @State private var showResult = false
    private var questions: [JSONValue] { quiz.solo["questions"].array }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if questions.isEmpty {
                    Text("10 questions aléatoires, toutes catégories. La correction apparaît après chaque réponse confirmée.").foregroundStyle(theme.muted)
                    Button("Commencer · 10 questions aléatoires") { Task { await quiz.startSolo(); index = 0; showResult = false } }.buttonStyle(PrimaryButtonStyle()).disabled(quiz.actionBusy).accessibilityIdentifier("quiz.solo.start")
                } else if showResult {
                    AppCard { VStack(spacing: 12) {
                        Image(systemName: "trophy.fill").foregroundStyle(theme.gold).font(.largeTitle)
                        Text("Quiz terminé").font(theme.title())
                        Text("\(quiz.soloResponses.values.filter { $0["isCorrect"].bool == true }.count) / \(questions.count)").font(.largeTitle)
                    }.frame(maxWidth: .infinity) }
                    Button("Nouvelle série") { Task { await quiz.startSolo(); if quiz.message == nil { index = 0; showResult = false } } }.buttonStyle(PrimaryButtonStyle()).disabled(quiz.actionBusy)
                } else if questions.indices.contains(index) {
                    let question = questions[index]
                    let response = quiz.soloResponses[question["id"].string ?? ""]
                    Text("Question \(index + 1) / \(questions.count)").font(.subheadline).foregroundStyle(theme.muted)
                    ProgressView(value: Double(index), total: Double(questions.count)).tint(theme.review)
                    QuizQuestionView(question: response?["question"] ?? question, response: response) { answer in
                        Task { await quiz.answerSolo(question: question, answerID: answer) }
                    }.disabled(quiz.actionBusy)
                    if response != nil {
                        Button(index + 1 == questions.count ? "Voir mon résultat" : "Question suivante") {
                            if index + 1 == questions.count { showResult = true } else { index += 1 }
                        }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("quiz.solo.next")
                    }
                }
                if quiz.actionBusy { ProgressView() }
                if let message = quiz.message { Text(message).font(.caption).foregroundStyle(theme.muted) }
            }.padding(18)
        }.background(theme.background).navigationTitle("Jouer en solo")
    }
}

struct QuizResponsesAdminView: View {
    @EnvironmentObject var quiz: QuizLibrary
    let questionID: String?
    @State private var rows: [JSONValue] = []
    @State private var loading = false
    @State private var hasMore = true
    @State private var error: String?
    var body: some View {
        List {
            if quiz.isAdmin {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    VStack(alignment: .leading, spacing: 7) {
                        Text(row["user_name"].string ?? "Compte sans profil").font(.headline)
                        Text("\(row["mode"].string ?? "Quiz") · \(row["answered_at"].string ?? "")").font(.caption)
                        Text(row["question"]["question"].string ?? "Question indisponible")
                        let answer = row["question"]["answers"].array.first { $0["id"].string == row["answer_id"].string }
                        Label(answer?["text"].string ?? "Réponse indisponible", systemImage: row["is_correct"].bool == true ? "checkmark.circle" : "xmark.circle")
                            .foregroundStyle(row["is_correct"].bool == true ? Color.green : Color.red)
                        Text("Quiz : \(row["quiz_id"].string ?? "")").font(.caption2).foregroundStyle(.secondary)
                    }.padding(.vertical, 4)
                }
                if rows.isEmpty && !loading && error == nil { Text("Aucune réponse enregistrée.") }
                if hasMore { Button("Charger les réponses suivantes") { Task { await load(reset: false) } }.disabled(loading) }
            } else { Text("Accès réservé à l’administrateur.") }
            if loading { ProgressView() }
            if let error { Text(error).font(.caption) }
        }.navigationTitle("Réponses aux quiz")
            .task { await load(reset: true) }
            .refreshable { await load(reset: true) }
            .onChange(of: quiz.isAdmin) { _, allowed in if !allowed { rows = []; hasMore = false } }
    }
    @MainActor private func load(reset: Bool) async {
        guard !loading, quiz.isAdmin else { return }
        loading = true; defer { loading = false }
        do {
            let page = try await quiz.adminResponses(questionID: questionID, offset: reset ? 0 : rows.count)
            if reset { rows = page } else { rows += page }
            hasMore = page.count == 50; error = nil
        } catch { self.error = "Rapport indisponible. Vérifie les droits, la connexion et le SQL quiz-solo-admin." }
    }
}
