// Prints the davening test table (Markdown) for DAVENING_RULES.md.
// Diaspora, daytime of each civil date; Kiddush Levanah evaluated at 20:00 UTC.
import Foundation

let dates: [(String, Int, Int, Int)] = [
    ("Chol HaMoed Sukkot", 2026, 9, 28),
    ("Shemini Atzeret", 2026, 10, 3),
    ("Isru Chag", 2026, 10, 5),
    ("Rosh Chodesh Cheshvan", 2026, 10, 12),
    ("Ordinary weekday", 2026, 10, 20),
    ("Day before tal u'matar", 2026, 12, 4),
    ("Chanukah + Rosh Chodesh Tevet", 2026, 12, 10),
    ("Asara b'Tevet", 2026, 12, 20),
    ("Purim Katan", 2027, 2, 21),
    ("Ta'anit Esther", 2027, 3, 22),
    ("Purim", 2027, 3, 23),
    ("Erev Pesach", 2027, 4, 21),
    ("Pesach I", 2027, 4, 22),
    ("Chol HaMoed Pesach", 2027, 4, 25),
    ("Lag BaOmer", 2027, 5, 25),
    ("Last Edot HaMizrach day", 2027, 6, 18),
    ("Shiva Asar b'Tammuz", 2027, 7, 22),
    ("Before Tisha b'Av", 2027, 8, 10),
    ("Tisha b'Av", 2027, 8, 12),
    ("After Tisha b'Av", 2027, 8, 13),
    ("18 Elul", 2027, 9, 20),
    ("Tzom Gedaliah", 2027, 10, 4),
]

let wdFmt = DateFormatter(); wdFmt.locale = Locale(identifier: "en_US_POSIX"); wdFmt.timeZone = TimeZone(identifier: "UTC"); wdFmt.dateFormat = "EEE yyyy-MM-dd"
var g = Calendar(identifier: .gregorian); g.timeZone = TimeZone(identifier: "UTC")!
let names: [HMonth: String] = [.tishrei: "Tishrei", .cheshvan: "Cheshvan", .kislev: "Kislev", .tevet: "Tevet", .shvat: "Shvat", .adar1: "Adar I", .adar: "Adar", .nisan: "Nisan", .iyar: "Iyar", .sivan: "Sivan", .tammuz: "Tammuz", .av: "Av", .elul: "Elul"]
let short: [Nusach: String] = [.ashkenaz: "Ashkenaz", .sefard: "Sefard", .chabad: "Chabad", .edot: "Edot HaMizrach"]

print("| Date | Hebrew date | Nusach | Menu lines |")
print("| --- | --- | --- | --- |")
for (label, y, m, d) in dates {
    let h = HDay(civilYear: y, month: m, day: d)
    let now = g.date(from: DateComponents(year: y, month: m, day: d, hour: 20))!
    var month = names[h.month]!
    if h.month == .adar && h.isLeapYear { month = "Adar II" }
    let heb = "\(h.day) \(month) \(h.year) (\(label))"
    var by: [Nusach: [String]] = [:]
    for n in Nusach.allCases { by[n] = DaveningRules.notes(for: h, nusach: n, israel: false, eveningStarted: false, now: now) }
    let common = by[.ashkenaz]!.filter { l in Nusach.allCases.allSatisfy { by[$0]!.contains(l) } }
    var first = true
    func row(_ who: String, _ lines: [String]) {
        guard !lines.isEmpty else { return }
        let text = lines.joined(separator: "; ").replacingOccurrences(of: "|", with: "\\|")
        // Empty cells are "| |" (one space) to satisfy markdownlint MD060.
        let date = first ? " \(wdFmt.string(from: h.civil)) " : " "
        let hebCell = first ? " \(heb) " : " "
        print("|\(date)|\(hebCell)| \(who) | \(text) |")
        first = false
    }
    row("All", common)
    for n in Nusach.allCases { row(short[n]!, by[n]!.filter { !common.contains($0) }) }
}
