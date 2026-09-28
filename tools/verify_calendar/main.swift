// Compares DayFacts with Hebcal's holiday data, day by day.
// Usage: verify_calendar <data-dir> <first-year> <last-year> (use tools/verify.sh)
import Foundation

struct Item: Decodable { let date: String; let category: String; let title: String; let yomtov: Bool? }
struct Resp: Decodable { let items: [Item] }

let g = HDay.gregCal
let iso = DateFormatter(); iso.locale = Locale(identifier: "en_US_POSIX"); iso.timeZone = TimeZone(identifier: "UTC"); iso.dateFormat = "yyyy-MM-dd"

var failures = 0, checked = 0
for israel in [false, true] {
    var rc = Set<String>(), fast = Set<String>(), yt = Set<String>(), chm = Set<String>(), purim = Set<String>()
    var chanukah: [String: Int] = [:]
    var first: Date?, last: Date?
    let years = Int(CommandLine.arguments[2])!...Int(CommandLine.arguments[3])!
    for y in years {
        let data = try! Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1] + "/hol_\(y)_\(israel ? "on" : "off").json"))
        for i in try! JSONDecoder().decode(Resp.self, from: data).items {
            let d = iso.date(from: i.date)!
            if first == nil || d < first! { first = d }
            if last == nil || d > last! { last = d }
            let t = i.title
            if i.category == "roshchodesh" { rc.insert(i.date) }
            if i.yomtov == true { yt.insert(i.date) }
            if t.contains("CH’’M") || t.contains("Hoshana Raba") { chm.insert(i.date) }
            if t == "Purim" { purim.insert(i.date) }
            if !t.hasPrefix("Erev"), ["Tzom Gedaliah", "Asara B’Tevet", "Ta’anit Esther", "Tzom Tammuz", "Tish’a B’Av"].contains(where: { t.hasPrefix($0) }) {
                fast.insert(i.date)
            }
            if t.hasPrefix("Chanukah: "), let n = Int(t.dropFirst(10).prefix(1)), t.contains("Candle") {
                chanukah[iso.string(from: d.addingTimeInterval(86_400))] = n   // day n is the day after candle n
            }
        }
    }
    // Stay inside the fetched years.
    var d = first!.addingTimeInterval(12 * 3600)
    while d <= last! {
        let key = iso.string(from: d)
        let f = DayFacts(h: HDay(noonUTC: d), israel: israel)
        func check(_ name: String, _ mine: Bool, _ theirs: Bool) {
            checked += 1
            if mine != theirs { failures += 1; print("MISMATCH \(israel ? "IL" : "DI") \(key) \(f.h.month) \(f.h.day): \(name) mine=\(mine) hebcal=\(theirs)") }
        }
        check("RoshChodesh", f.isRoshChodesh, rc.contains(key))
        check("Fast", f.fast != nil, fast.contains(key))
        check("YomTov", f.isYomTov, yt.contains(key))
        check("CholHamoed", f.isCholHamoed, chm.contains(key))
        check("Purim", f.isPurim, purim.contains(key))
        checked += 1
        if f.chanukahDay != chanukah[key] && !(f.chanukahDay == 8 && chanukah[key] == nil) {
            failures += 1; print("MISMATCH \(key) Chanukah mine=\(String(describing: f.chanukahDay)) hebcal=\(String(describing: chanukah[key]))")
        }
        d = d.addingTimeInterval(86_400)
    }
}
print("checked \(checked) facts, \(failures) mismatches")
exit(failures == 0 ? 0 : 1)   // tools/verify.sh reports this exit code
