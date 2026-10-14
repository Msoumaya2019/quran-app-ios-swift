import SwiftUI

@MainActor final class ThemeManager: ObservableObject {
    @AppStorage("native.theme") var name = "white" { willSet { objectWillChange.send() } }
    @AppStorage("native.accent") var accentName = "prune" { willSet { objectWillChange.send() } }
    @AppStorage("native.font") var fontName = "system" { willSet { objectWillChange.send() } }
    @AppStorage("native.appearance") var appearance = "system" { willSet { objectWillChange.send() } }
    var preferredScheme: ColorScheme? { appearance == "dark" ? .dark : appearance == "light" ? .light : nil }
    private func adaptive(_ light: String, _ dark: String) -> Color {
        Color(UIColor { traits in UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light)) })
    }
    private var importedAccount: UUID?
    func importPreferences(state: JSONValue, userID: UUID) {
        guard !state.object.isEmpty, importedAccount != userID else { return }; importedAccount = userID
        if UserDefaults.standard.string(forKey: "native.preferences.owner") == userID.uuidString { return }
        UserDefaults.standard.set(userID.uuidString, forKey: "native.preferences.owner")
        name = state["theme"].string ?? "white"
        accentName = state["accent"].string ?? (name == "classic" ? "green" : name == "feminine" ? "rose" : "prune")
        fontName = state["uiFont"].string ?? "system"
    }
    var accent: Color { adaptive(["prune":"7B285C", "rose":"A95069", "green":"54734E", "gold":"916825"][accentName] ?? "7B285C", ["prune":"D49ABC", "rose":"EDA4B9", "green":"A4C99B", "gold":"E1BC78"][accentName] ?? "D49ABC") }
    var background: Color { adaptive( ["white":"FCFBF9", "classic":"F7F5EE", "feminine":"FFFAFC", "lilac":"FBF9FF", "night":"F7F7F4"][name] ?? "FCFBF9", "151817") }
    var surface: Color { adaptive(["classic":"FFFDF7", "feminine":"FFF5F8", "lilac":"FFFCFF", "night":"FFFDF8"][name] ?? "FFFFFF", "222725") }
    var onAccent: Color { adaptive("FFFFFF", "151817") }
    var text: Color { adaptive("241C2B", "EFECE5") }
    var muted: Color { adaptive("746D7B", "BCB8C1") }
    var border: Color { adaptive("ECE8E5", "414744") }
    var gold: Color { adaptive("C89A52", "E1BC78") }
    var review: Color { adaptive("246B48", "90C8AC") }
    var hero: String { ["white":"HeroWhite", "classic":"HeroGreen", "feminine":"HeroRose", "lilac":"HeroLilac", "night":"HeroNight"][name] ?? "HeroWhite" }
    func title(_ style: Font.TextStyle = .title3) -> Font { .system(style, design: fontName == "system" ? .default : .serif).weight(.semibold) }
}
extension Color {
    init(hex: String) {
        let n = UInt64(hex, radix: 16) ?? 0
        self.init(.sRGB, red: Double((n >> 16) & 255)/255, green: Double((n >> 8) & 255)/255, blue: Double(n & 255)/255, opacity: 1)
    }
}
