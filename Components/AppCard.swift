import SwiftUI

struct AppCard<Content: View>: View {
    @EnvironmentObject var theme: ThemeManager
    @ViewBuilder let content: Content
    var body: some View {
        content.padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(theme.border, lineWidth: 1))
            .shadow(color: .black.opacity(0.025), radius: 8, y: 3)
    }
}
struct SectionHeader: View {
    @EnvironmentObject var theme: ThemeManager
    let title: String
    let action: String
    let onAction: () -> Void
    var body: some View {
        HStack { Text(title).font(theme.title()).foregroundStyle(theme.accent); Spacer(); Button(action, action: onAction).font(.caption).frame(minHeight: 44) }.buttonStyle(.plain).foregroundStyle(theme.accent)
    }
}
struct PrimaryButtonStyle: ButtonStyle {
    @EnvironmentObject var theme: ThemeManager
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.subheadline.weight(.semibold)).foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 44).background(theme.accent, in: RoundedRectangle(cornerRadius: 14)).opacity(configuration.isPressed ? 0.8 : 1)
    }
}
