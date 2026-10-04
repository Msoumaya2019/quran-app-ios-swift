import SwiftUI

struct QuizView: View {
    @EnvironmentObject var quiz: QuizLibrary
    @EnvironmentObject var theme: ThemeManager
    private var today: String { LocalCalendar.key(.now) }
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "trophy.fill").font(.largeTitle).foregroundStyle(theme.gold)
                Text("Teste tes connaissances").font(theme.title())
                Text("Coran, Tajwid, Prophètes, Sîra et plus encore").font(.caption).foregroundStyle(theme.muted)
                NavigationLink { QuizDailyView() } label: {
                    AppCard { VStack(alignment: .leading, spacing: 8) {
                        Label("Question du jour", systemImage: "sun.max.fill").font(theme.title()).foregroundStyle(theme.gold)
                        Text("Une nouvelle question chaque jour").font(.subheadline)
                        Text(quiz.cache?.response(day: today) != nil ? "✓ Terminée aujourd’hui" : quiz.cache?.data["day"].string == today && quiz.cache?.data["daily"] != .null ? "Disponible aujourd’hui" : "À actualiser").font(.caption).foregroundStyle(theme.review)
                    }.frame(maxWidth: .infinity, alignment: .leading) }
                }.buttonStyle(.plain).accessibilityIdentifier("quiz.daily")
                NavigationLink { QuizChallengesView() } label: {
                    AppCard { VStack(alignment: .leading, spacing: 8) {
                        Label("Défis entre amis", systemImage: "person.2.fill").font(theme.title())
                        Text("Affronte tes amis sur 5 ou 10 questions").font(.subheadline)
                    }.foregroundStyle(theme.accent).frame(maxWidth: .infinity, alignment: .leading) }
                }.buttonStyle(.plain)
                NavigationLink("Historique") { QuizHistoryView() }.buttonStyle(PrimaryButtonStyle())
                if let message = quiz.message { Text(message).font(.caption).foregroundStyle(theme.muted) }
            }.padding(18)
        }.background(theme.background).navigationTitle("Quiz")
            .task { await quiz.refresh() }.refreshable { await quiz.refresh() }
    }
}

struct QuizDailyView: View {
    @EnvironmentObject var quiz: QuizLibrary
    @EnvironmentObject var theme: ThemeManager
    var body: some View {
        let day = LocalCalendar.key(.now)
        let response = quiz.cache?.response(day: day)
        let question = response?["question"] ?? (quiz.cache?.data["day"].string == day ? quiz.cache?.data["daily"] ?? .null : .null)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if question != .null {
                    QuizQuestionView(question: question, response: response) { answer in
                        quiz.answer(question, answerID: answer)
                        Task { await quiz.refresh() }
                    }
                } else {
                    Text(quiz.loading ? "Chargement de la question…" : "Aucune question du jour disponible. Connecte-toi pour actualiser le Quiz.").foregroundStyle(theme.muted)
                }
                if let message = quiz.message { Text(message).font(.caption).foregroundStyle(theme.muted) }
            }.padding(18)
        }.background(theme.background).navigationTitle("Question du jour").navigationBarTitleDisplayMode(.inline)
            .task { await quiz.refresh() }
    }
}

struct QuizQuestionView: View {
    @EnvironmentObject var theme: ThemeManager
    let question: JSONValue
    let response: JSONValue?
    let answer: (String) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(question["category"].string ?? "Quiz").font(.caption).foregroundStyle(theme.gold)
            Text(question["question"].string ?? "").font(theme.title(.headline))
            ForEach(question["answers"].array, id: \.selfID) { option in
                let id = option["id"].string ?? ""
                let selected = response?["selectedAnswerId"].string == id
                let solution = question["correctAnswerId"].string
                let color: Color = response == nil || solution == nil ? theme.accent : id == solution ? theme.review : selected ? .red : theme.muted
                Button { answer(id) } label: {
                    HStack { Text(option["text"].string ?? ""); Spacer(); if response != nil, id == solution { Image(systemName: "checkmark.circle.fill") } else if selected { Image(systemName: solution == nil ? "clock" : "xmark.circle.fill") } }
                        .font(.subheadline).foregroundStyle(color).padding(14).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .background(color.opacity(selected || (response != nil && id == solution) ? 0.09 : 0.02), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.25)))
                }.buttonStyle(.plain).disabled(response != nil).accessibilityIdentifier("quiz.answer." + id)
            }
            if let response {
                AppCard { VStack(alignment: .leading, spacing: 8) {
                    Text(response["pending"].bool == true ? "Réponse enregistrée — correction après synchronisation" : response["isCorrect"].bool == true ? "Bonne réponse !" : "Voici la correction").font(theme.title(.subheadline))
                    ForEach(["explanation", "arabic", "translation", "sourceTitle", "sourceReference"], id: \.self) { key in
                        if let text = question[key].string, !text.isEmpty { Text(text).font(.subheadline) }
                    }
                    if let source = question["sourceUrl"].string, let url = URL(string: source), url.scheme == "https" { Link("Consulter la source", destination: url).frame(minHeight: 44) }
                } }
            }
        }
    }
}
private extension JSONValue { var selfID: String { self["id"].string ?? "" } }

struct QuizHistoryView: View {
    @EnvironmentObject var quiz: QuizLibrary
    @EnvironmentObject var theme: ThemeManager
    var body: some View {
        List {
            ForEach(quiz.cache?.data["responses"].array ?? [], id: \.selfIDForDay) { response in
                NavigationLink {
                    ScrollView { QuizQuestionView(question: response["question"], response: response, answer: { _ in }).padding(18) }.navigationTitle("Correction")
                } label: {
                    HStack { Text(response["day"].string ?? ""); Spacer(); Image(systemName: response["isCorrect"].bool == true ? "checkmark.circle" : "xmark.circle").foregroundStyle(response["isCorrect"].bool == true ? theme.review : .red) }
                }
            }
            ForEach(quiz.cache?.pending ?? [], id: \.day) { row in Text("\(row.day) · À synchroniser").foregroundStyle(theme.muted) }
        }.navigationTitle("Historique")
    }
}
private extension JSONValue { var selfIDForDay: String { self["day"].string ?? "" } }
