//
//  DaveningRules.swift
//  Hebcal4Menubar
//
//  Today's changes to the davening, computed locally from the Hebrew date.
//  The rules are listed and justified in DAVENING_RULES.md; keep the two in
//  step. Out of scope: personal situations (mourner, bris, chatan) and
//  community-specific customs.
//

import Foundation

enum Nusach: String, CaseIterable {
    case ashkenaz, sefard, chabad, edot

    var title: String {
        switch self {
        case .ashkenaz: return "Ashkenaz"
        case .sefard:   return "Sefard (chassidic)"
        case .chabad:   return "Chabad"
        case .edot:     return "Edot HaMizrach"
        }
    }
}

/// Calendar facts about one Hebrew day, for either Israel or the diaspora.
struct DayFacts {
    let h: HDay
    let israel: Bool

    var isRoshChodesh: Bool { h.day == 30 || (h.day == 1 && h.month != .tishrei) }

    var isYomTov: Bool {
        switch h.month {
        case .tishrei: return [1, 2, 10, 15, 22].contains(h.day) || (!israel && [16, 23].contains(h.day))
        case .nisan:   return [15, 21].contains(h.day) || (!israel && [16, 22].contains(h.day))
        case .sivan:   return h.day == 6 || (!israel && h.day == 7)
        default:       return false
        }
    }

    var isCholHamoedSukkot: Bool { h.is(.tishrei, (israel ? 16 : 17)...21) }
    var isCholHamoedPesach: Bool { h.is(.nisan, (israel ? 16 : 17)...20) }
    var isCholHamoed: Bool { isCholHamoedSukkot || isCholHamoedPesach }

    /// 1…8 during Chanukah, else nil.
    var chanukahDay: Int? {
        if h.month == .kislev && h.day >= 25 { return h.day - 24 }
        if h.month == .tevet {
            let n = (h.previousMonthLength - 24) + h.day
            return n <= 8 ? n : nil
        }
        return nil
    }

    var isPurim: Bool { h.is(.adar, 14) }
    var isShushanPurim: Bool { h.is(.adar, 15) }
    var isPurimKatan: Bool { h.isLeapYear && h.is(.adar1, 14...15) }

    /// Name of today's public fast (Yom Kippur excluded), with postponements.
    var fast: String? {
        let wd = h.weekday
        if (h.is(.tishrei, 3) && wd != 7) || (h.is(.tishrei, 4) && wd == 1) { return "Tzom Gedaliah" }
        if h.is(.tevet, 10) { return "Asara b'Tevet" }
        if (h.is(.adar, 13) && wd != 7) || (h.is(.adar, 11) && wd == 5) { return "Ta'anit Esther" }
        if (h.is(.tammuz, 17) && wd != 7) || (h.is(.tammuz, 18) && wd == 1) { return "Shiva Asar b'Tammuz" }
        if isTishaBav { return "Tisha b'Av" }
        return nil
    }

    var isTishaBav: Bool { (h.is(.av, 9) && h.weekday != 7) || (h.is(.av, 10) && h.weekday == 1) }

    var isAseretYemeiTeshuvah: Bool { h.is(.tishrei, 1...10) }

    /// Days on which the weekday Amidah (and Tachanun etc.) is not said.
    var isShabbatOrYomTov: Bool { h.isShabbat || isYomTov }

    /// Rain season for "mashiv haRuach": Shemini Atzeret → 1st day Pesach.
    var isGeshemSeason: Bool {
        switch h.month {
        case .tishrei: return h.day > 22
        case .nisan:   return h.day < 15
        case .cheshvan, .kislev, .tevet, .shvat, .adar1, .adar: return true
        default:       return false
        }
    }

    /// Season for "v'ten tal u'matar" (weekday Amidah).
    var isTalUmatarSeason: Bool {
        if israel {
            if h.month == .cheshvan { return h.day >= 7 }
            if h.month == .nisan { return h.day <= 14 }
            return h.month > .cheshvan && h.month < .nisan
        }
        // Diaspora: from Maariv on the evening of 4 December (5 December
        // when the next civil year is a leap year) until Pesach.
        let c = h.civilComponents
        if c.month == 12 { return c.day! >= Self.talUmatarStartDay(civilYear: c.year!) }
        if (1...4).contains(c.month!) {
            if h.month == .nisan { return h.day <= 14 }
            return [.tevet, .shvat, .adar1, .adar, .kislev].contains(h.month)
        }
        return false
    }

    /// Civil December day whose daytime is the first diaspora tal u'matar day
    /// (the Hebrew day that begins on the evening of 4 or 5 December).
    static func talUmatarStartDay(civilYear y: Int) -> Int {
        let next = y + 1
        let nextIsLeap = (next % 4 == 0 && next % 100 != 0) || next % 400 == 0
        return nextIsLeap ? 6 : 5
    }

    /// Tachanun is omitted all day.
    func omitsTachanun(_ n: Nusach) -> Bool {
        if isRoshChodesh || chanukahDay != nil || isTishaBav { return true }
        switch h.month {
        case .nisan: return true
        case .iyar:  if [14, 18].contains(h.day) { return true }
        case .sivan: if h.day <= (n == .edot ? 13 : 12) { return true }
        case .av:    if h.day == 15 { return true }
        case .tishrei: if h.day >= 9 { return true }
        case .shvat: if h.day == 15 { return true }
        case .adar:  if [14, 15].contains(h.day) { return true }
        case .adar1: if h.isLeapYear && [14, 15].contains(h.day) { return true }
        default: break
        }
        if n == .chabad {
            if h.is(.elul, 18) || h.is(.kislev, 19...20) || h.is(.shvat, 10) || h.is(.tammuz, 12...13) {
                return true
            }
        }
        return false
    }

    /// 1…49 during the Omer (the count said on the evening that begins this day).
    var omerDay: Int? {
        switch h.month {
        case .nisan where h.day >= 16: return h.day - 15
        case .iyar:                    return 15 + h.day
        case .sivan where h.day <= 5:  return 44 + h.day
        default:                       return nil
        }
    }
}

enum DaveningRules {

    /// Lines for the menu, most important first.
    /// - Parameter eveningStarted: true when the displayed Hebrew day began at
    ///   sunset (so "tonight" already belongs to this day).
    static func notes(for h: HDay, nusach n: Nusach, israel: Bool,
                      eveningStarted: Bool, now: Date = Date()) -> [String] {
        let f = DayFacts(h: h, israel: israel)
        let tomorrow = DayFacts(h: h.adding(1), israel: israel)
        let weekday = !f.isShabbatOrYomTov
        var out: [String] = []

        // Seasonal: rain and dew
        if h.is(.tishrei, 22) {
            out.append("Mashiv haRuach u'morid haGeshem from Mussaf")
        } else if h.is(.nisan, 15) {
            out.append(summerGeshem(n, israel) + " from Mussaf")
        } else {
            out.append(f.isGeshemSeason ? "Mashiv haRuach u'morid haGeshem" : summerGeshem(n, israel))
        }
        if weekday {
            out.append(f.isTalUmatarSeason ? winterBarech(n) : summerBarech(n))
        }
        if !f.isTalUmatarSeason && tomorrow.isTalUmatarSeason && !eveningStarted {
            out.append(winterBarech(n) + " begins tonight at Maariv")
        }

        // Day inserts
        if f.isRoshChodesh || f.isCholHamoed { out.append("Ya'aleh v'yavo") }
        if f.chanukahDay != nil || f.isPurim { out.append("Al haNissim") }
        if let fast = f.fast {
            out.append(n == .edot ? "Aneinu (\(fast)) at Shacharit and Mincha"
                                  : "Aneinu (\(fast)) at Mincha, chazan also at Shacharit")
            if f.isTishaBav { out.append("Nachem at Mincha") }
        }
        if f.isAseretYemeiTeshuvah {
            out.append("Aseret Yemei Teshuvah: haMelech haKadosh, haMelech haMishpat, Zochreinu, Mi Chamocha, U'chtov, B'sefer Chayim, Oseh haShalom")
        }
        let avinuMalkeinu: Bool = {
            if f.isAseretYemeiTeshuvah && !h.isShabbat { return true }
            if n != .edot, f.fast != nil, !f.isTishaBav { return true }
            return false
        }()
        if avinuMalkeinu { out.append("Avinu Malkeinu") }

        // Hallel
        if let hallel = hallel(f, israel) {
            out.append(hallel == .full ? "Full Hallel"
                       : (n == .edot ? "Half Hallel (no beracha)" : "Half Hallel"))
        }

        // Tachanun and omitted psalms (weekdays only)
        if weekday {
            if f.omitsTachanun(n) {
                out.append("No Tachanun")
            } else if tomorrow.omitsTachanun(n) || tomorrow.h.isShabbat || tomorrow.isYomTov {
                out.append("Tachanun at Shacharit only (none at Mincha)")
            } else {
                out.append("Tachanun")
            }
            let erevPesach = h.is(.nisan, 14), erevYK = h.is(.tishrei, 9)
            if f.isRoshChodesh || f.chanukahDay != nil || f.isPurim || f.isShushanPurim
                || erevPesach || f.isCholHamoed || erevYK || f.isTishaBav {
                out.append("Omit Lamnatzeach")
            }
            if erevPesach || f.isCholHamoedPesach || erevYK { out.append("Omit Mizmor l'Todah") }
        }

        // Additions and counts
        let lDavidEnd = n == .chabad ? 21 : 22
        if h.month == .elul || h.is(.tishrei, 1...lDavidEnd) {
            out.append(n == .edot ? "L'David Hashem Ori (many say it all year)" : "L'David Hashem Ori")
        }
        if let omer = omerLine(f, n, eveningStarted: eveningStarted) { out.append(omer) }
        if let kl = kiddushLevanah(h, n, now: now) { out.append(kl) }

        return out
    }

    // MARK: Pieces

    private enum HallelKind { case full, half }

    private static func hallel(_ f: DayFacts, _ israel: Bool) -> HallelKind? {
        let h = f.h
        if h.is(.tishrei, 15...(israel ? 22 : 23)) || f.chanukahDay != nil
            || h.is(.nisan, 15...(israel ? 15 : 16)) || h.is(.sivan, 6...(israel ? 6 : 7)) {
            return .full
        }
        if f.isRoshChodesh || h.is(.nisan, (israel ? 16 : 17)...(israel ? 21 : 22)) { return .half }
        return nil
    }

    private static func summerGeshem(_ n: Nusach, _ israel: Bool) -> String {
        (n == .ashkenaz && !israel) ? "Summer: no morid haTal" : "Morid haTal"
    }
    private static func winterBarech(_ n: Nusach) -> String {
        n == .edot ? "Barech Aleinu (winter)" : "V'ten tal u'matar livracha"
    }
    private static func summerBarech(_ n: Nusach) -> String {
        n == .edot ? "Barchenu (summer)" : "V'ten beracha"
    }

    private static func omerText(_ day: Int, _ n: Nusach) -> String {
        let suffix = n == .ashkenaz ? "baOmer" : "laOmer"
        let weeks = day / 7, days = day % 7
        guard weeks > 0 else { return "\(day) \(day == 1 ? "day" : "days") \(suffix)" }
        var parts = "\(weeks) \(weeks == 1 ? "week" : "weeks")"
        if days > 0 { parts += " and \(days) \(days == 1 ? "day" : "days")" }
        return "\(day) days — \(parts) — \(suffix)"
    }

    private static func omerLine(_ f: DayFacts, _ n: Nusach, eveningStarted: Bool) -> String? {
        if eveningStarted {
            // The evening that began this Hebrew day is "tonight".
            return f.omerDay.map { "Sefirat haOmer tonight: " + omerText($0, n) }
        }
        let next = DayFacts(h: f.h.adding(1), israel: f.israel).omerDay
        if let next { return "Sefirat haOmer tonight: " + omerText(next, n) }
        return nil
    }

    private static func kiddushLevanah(_ h: HDay, _ n: Nusach, now: Date) -> String? {
        let molad = h.adding(1 - h.day).molad          // molad of this month
        let waitDays: Double = n == .ashkenaz ? 3 : 7
        let start = molad.addingTimeInterval(waitDays * 86_400)
        let end = molad.addingTimeInterval(14 * 86_400 + 18 * 3600 + 22 * 60 + 20)
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE d MMM, HH:mm"
        guard now < end else { return nil }
        // Custom: wait until after Yom Kippur, and until after Tisha b'Av.
        if h.is(.tishrei, 1...10) && now >= start { return "Kiddush Levanah after Yom Kippur" }
        let tishaBavPostponed = h.adding(9 - h.day).isShabbat   // 9 Av on Shabbat → fast on 10 Av
        if h.is(.av, 1...(tishaBavPostponed ? 10 : 9)) && now >= start {
            return "Kiddush Levanah after Tisha b'Av"
        }
        if now < start && start.timeIntervalSince(now) < 2 * 86_400 {
            return "Kiddush Levanah from \(fmt.string(from: start))"
        }
        if now >= start && now < end {
            return "Kiddush Levanah until \(fmt.string(from: end))"
        }
        return nil
    }
}
