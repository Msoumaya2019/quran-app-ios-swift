import Foundation

enum MushafVerseNumber {
    static func text(_ number: Int) -> String {
        guard number > 0 else { return "" }
        return String(number).unicodeScalars.map { String(UnicodeScalar(0x0660 + $0.value - 0x0030)!) }.joined()
    }
}
