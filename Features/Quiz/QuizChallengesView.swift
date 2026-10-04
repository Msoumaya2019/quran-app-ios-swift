import SwiftUI

struct QuizChallengesView: View {
    @EnvironmentObject var quiz: QuizLibrary
    @EnvironmentObject var friends: FriendsLibrary
    @EnvironmentObject var theme: ThemeManager
    @State private var friend = ""
    @State private var count = 10
    @State private var set = ""
    init(initialFriend: String = "") { _friend = State(initialValue: initialFriend) }
    var body: some View {
        List {
            Section("Nouveau défi") {
                Picker("Ami", selection: $friend) {
                    Text("Choisir un ami").tag("")
                    ForEach(friends.snapshot?.items() ?? []) { item in Text(item.name).tag(item.otherID) }
                }
                Picker("Questions", selection: $count) { Text("5 questions").tag(5); Text("10 questions").tag(10) }.disabled(!set.isEmpty)
                Picker("Thème", selection: $set) {
                    Text("Toutes les questions").tag("")
                    ForEach(quiz.cache?.data["quizSets"].array ?? [], id: \.quizID) { row in Text(row["title"].string ?? "Quiz").tag(row["id"].string ?? "") }
                }.onChange(of: set) { _, value in if !value.isEmpty { count = 10 } }
                Button("Lancer le défi") { Task { await quiz.createChallenge(friend: friend, count: count, set: set.isEmpty ? nil : set) } }.disabled(friend.isEmpty || quiz.actionBusy)
                Text("48 heures pour répondre. Une connexion est nécessaire pour lancer ou jouer un défi.").font(.caption).foregroundStyle(theme.muted)
            }
            Section("Mes défis") {
                ForEach(quiz.cache?.data["challenges"].array ?? [], id: \.quizID) { row in
                    if let owner = quiz.cache?.owner {
                        let p = QuizChallengeProjection(value: row, owner: owner)
                        NavigationLink { QuizChallengeView(id: p.id) } label: { VStack(alignment: .leading, spacing: 5) { Text(p.otherName); Text("\(p.status) · \(row["questionCount"].int ?? 10) questions").font(.caption).foregroundStyle(theme.muted) } }
                    }
                }
            }
            if let message = quiz.message { Text(message).font(.caption).foregroundStyle(theme.muted) }
        }.navigationTitle("Défis entre amis").task { await friends.refresh(); await quiz.refresh() }.refreshable { await quiz.refresh() }
    }
}

struct QuizChallengeView: View {
    @EnvironmentObject var quiz: QuizLibrary
    @EnvironmentObject var theme: ThemeManager
    let id: String
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let row = quiz.cache?.data["challenges"].array.first(where: { $0["id"].string == id }), let owner = quiz.cache?.owner {
                    let p = QuizChallengeProjection(value: row, owner: owner)
                    Text(p.otherName).font(theme.title())
                    Text(p.status).foregroundStyle(theme.review)
                    if p.completed {
                        let creator = row["creatorId"].string ?? "", opponent = row["opponentId"].string ?? ""
                        Text("\(row["creatorName"].string ?? "Joueur") : \(p.score(user: creator) ?? 0) / \(row["questionCount"].int ?? 10)")
                        Text("\(row["opponentName"].string ?? "Ami") : \(p.score(user: opponent) ?? 0) / \(row["questionCount"].int ?? 10)")
                        Text(p.score(user: creator) == p.score(user: opponent) ? "Égalité" : "🏆 \(row[p.score(user: creator)! > p.score(user: opponent)! ? "creatorName" : "opponentName"].string ?? "Joueur") remporte le défi")
                        ForEach(row["questions"].array, id: \.quizID) { question in
                            QuizQuestionView(question: question, response: p.ownAnswers.first { $0["questionId"].string == question["id"].string }, answer: { _ in })
                        }
                    } else if !p.expired, let question = p.next {
                        Text("\(p.ownAnswers.count + 1) / \(row["questionCount"].int ?? 10)").font(.caption)
                        QuizQuestionView(question: question, response: nil) { answer in Task { await quiz.answerChallenge(challenge: id, question: question["id"].string ?? "", answer: answer) } }.disabled(quiz.actionBusy || quiz.loading)
                    } else if !p.expired { Text("Tes réponses ont été enregistrées. En attente de \(p.otherName).") }
                    else { Text("Ce défi a expiré. Aucun vainqueur n’est attribué.") }
                }
                if let message = quiz.message { Text(message).font(.caption).foregroundStyle(theme.muted) }
            }.padding(18)
        }.background(theme.background).navigationTitle("Défi").navigationBarTitleDisplayMode(.inline)
            .task { await quiz.refresh() }.refreshable { await quiz.refresh() }
    }
}
private extension JSONValue { var quizID: String { self["id"].string ?? "" } }
