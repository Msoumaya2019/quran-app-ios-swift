import SwiftUI

@MainActor final class ThemeManager: ObservableObject {
    @AppStorage("native.theme") var name = "white" { willSet { objectWillChange.send() } }
    @AppStorage("native.accent") var accentName = "prune" { willSet { objectWillChange.send() } }
    @AppStorage("native.font") var fontName = "system" { willSet { objectWillChange.send() } }
    private var importedAccount: UUID?
    func importPreferences(state: JSONValue, userID: UUID) {
        guard !state.object.isEmpty, importedAccount != userID else { return }; importedAccount = userID
        if UserDefaults.standard.string(forKey: "native.preferences.owner") == userID.uuidString { return }
        UserDefaults.standard.set(userID.uuidString, forKey: "native.preferences.owner")
        name = state["theme"].string ?? "white"
        accentName = state["accent"].string ?? (name == "classic" ? "green" : name == "feminine" ? "rose" : "prune")
        fontName = state["uiFont"].string ?? "system"
    }
    var accent: Color { Color(hex: ["prune":"7B285C", "rose":"A95069", "green":"54734E", "gold":"916825"][accentName] ?? "7B285C") }
    var background: Color { Color(hex: ["white":"FCFBF9", "classic":"F7F5EE", "feminine":"FFFAFC", "lilac":"FBF9FF", "night":"F7F7F4"][name] ?? "FCFBF9") }
    var surface: Color { name == "white" ? .white : Color(hex: ["classic":"FFFDF7", "feminine":"FFF5F8", "lilac":"FFFCFF", "night":"FFFDF8"][name] ?? "FFFFFF") }
    var text: Color { Color(hex: "241C2B") }
    var muted: Color { Color(hex: "746D7B") }
    var border: Color { Color(hex: "ECE8E5") }
    var gold: Color { Color(hex: "C89A52") }
    var review: Color { Color(hex: "246B48") }
    var hero: String { ["white":"HeroWhite", "classic":"HeroGreen", "feminine":"HeroRose", "lilac":"HeroLilac", "night":"HeroNight"][name] ?? "HeroWhite" }
    func title(_ style: Font.TextStyle = .title3) -> Font { .system(style, design: fontName == "system" ? .default : .serif).weight(.semibold) }
}
extension Color {
    init(hex: String) {
        let n = UInt64(hex, radix: 16) ?? 0
        self.init(.sRGB, red: Double((n >> 16) & 255)/255, green: Double((n >> 8) & 255)/255, blue: Double(n & 255)/255, opacity: 1)
    }
}
