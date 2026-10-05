import SwiftUI

struct ProblemReportsAdminView: View {
    @EnvironmentObject var reports: ProblemReportLibrary
    @EnvironmentObject var theme: ThemeManager
    var body: some View {
        List {
            if reports.adminLoading { ProgressView() }
            if let error = reports.adminError { Text(error).font(.caption).foregroundStyle(theme.muted) }
            if !reports.adminLoading && reports.adminReports.isEmpty { Text("Aucun signalement disponible").foregroundStyle(theme.muted) }
            ForEach(reports.adminReports) { report in
                NavigationLink { ProblemReportDetail(report: report) } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack { Label(report.type.rawValue, systemImage: report.type.icon).foregroundStyle(theme.review); Spacer(); Text(report.status == "resolved" ? "Résolu" : "À traiter").font(.caption).foregroundStyle(theme.muted) }
                        Text(report.description).font(.subheadline).lineLimit(2)
                        Text(String(report.created_at.prefix(10))).font(.caption).foregroundStyle(theme.muted)
                    }.padding(.vertical, 4)
                }
            }
        }.navigationTitle("Signalements").navigationBarTitleDisplayMode(.inline)
            .task { await reports.refreshAdmin() }.refreshable { await reports.refreshAdmin() }
    }
}
private struct ProblemReportDetail: View {
    @EnvironmentObject var reports: ProblemReportLibrary
    @EnvironmentObject var theme: ThemeManager
    let report: ProblemReport
    @State private var imageURL: URL?
    @State private var resolving = false
    private var resolved: Bool { reports.adminReports.first(where: { $0.id == report.id })?.status == "resolved" }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Label(report.type.rawValue, systemImage: report.type.icon).font(theme.title()).foregroundStyle(theme.review)
                Text(report.description).textSelection(.enabled)
                Text("\(report.created_at) • \(report.platform) • v\(report.app_version)").font(.caption).foregroundStyle(theme.muted)
                Text(report.user_id.uuidString).font(.caption2).textSelection(.enabled).foregroundStyle(theme.muted)
                if let imageURL { AsyncImage(url: imageURL) { image in image.resizable().scaledToFit() } placeholder: { ProgressView() } }
                if let error = reports.adminError { Text(error).font(.caption).foregroundStyle(theme.muted) }
                if !resolved {
                    Button("Marquer comme résolu") { Task { resolving = true; await reports.resolve(report); resolving = false } }.buttonStyle(PrimaryButtonStyle()).disabled(resolving)
                } else { Label("Résolu", systemImage: "checkmark.circle").foregroundStyle(theme.review) }
            }.padding(20)
        }.background(theme.background).navigationTitle("Signalement").navigationBarTitleDisplayMode(.inline)
            .task { imageURL = await reports.adminScreenshot(report) }
    }
}
