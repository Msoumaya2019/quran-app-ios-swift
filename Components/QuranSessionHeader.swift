import SwiftUI

struct QuranSessionHeader: View {
    let context: QuranSessionContext
    let source: QuranSource
    let catalog: QuranCatalog
    @EnvironmentObject private var theme: ThemeManager
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "book.fill").font(.headline)
            VStack(alignment: .leading, spacing: 2) {
                Text(context.title).font(.subheadline.weight(.semibold))
                Text("\(context.range.count) versets").font(.caption2)
            }.lineLimit(2)
            Spacer(minLength: 4)
            Rectangle().fill(theme.review.opacity(0.2)).frame(width: 1, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("Pages").font(.caption2)
                Text(pageLabel).font(.caption.weight(.medium))
            }
        }.foregroundStyle(theme.review).padding(.horizontal, 14).padding(.vertical, 9)
            .background(theme.review.opacity(0.06), in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(theme.review.opacity(0.1), lineWidth: 1))
            .padding(.horizontal, 12).padding(.vertical, 4).accessibilityElement(children: .contain).accessibilityIdentifier("quran.session.header")
    }
    private var pageLabel: String {
        let first = QuranSourceMapping.page(source: source, verseID: context.range.start, catalog: catalog)
        let last = QuranSourceMapping.page(source: source, verseID: context.range.end, catalog: catalog)
        return first == last ? String(first) : "\(first) → \(last)"
    }
}
