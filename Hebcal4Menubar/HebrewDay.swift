//
//  HebrewDay.swift
//  Hebcal4Menubar
//
//  A Hebrew calendar day, computed locally with Foundation's Hebrew
//  calendar, plus the molad (mean new moon). Used by DaveningRules so the
//  davening section works offline and does not depend on Hebcal.
//

import Foundation

/// Hebrew months in Foundation's numbering. `adar1` exists only in leap
/// years; `adar` is Adar in a common year and Adar II in a leap year.
enum HMonth: Int, Comparable {
    case tishrei = 1, cheshvan, kislev, tevet, shvat, adar1, adar
    case nisan, iyar, sivan, tammuz, av, elul

    static func < (a: HMonth, b: HMonth) -> Bool { a.rawValue < b.rawValue }
}

struct HDay {
    let year: Int
    let month: HMonth
    let day: Int
    /// 1 = Sunday … 7 = Shabbat
    let weekday: Int
    /// Noon UTC of the civil (daytime) date of this Hebrew day.
    let civil: Date

    static let hebrewCal: Calendar = {
        var c = Calendar(identifier: .hebrew)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    static let gregCal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    /// The Hebrew day whose daytime falls on this civil date.
    init(civilYear y: Int, month m: Int, day d: Int) {
        let date = Self.gregCal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
        self.init(noonUTC: date)
    }

    init(noonUTC date: Date) {
        let c = Self.hebrewCal.dateComponents([.year, .month, .day, .weekday], from: date)
        year = c.year!
        month = HMonth(rawValue: c.month!)!
        day = c.day!
        weekday = c.weekday!
        civil = date
    }

    /// The Hebrew day in effect at `instant` in the local time zone.
    /// `afterSunset` advances to the next Hebrew day (the evening rule).
    static func current(at instant: Date, afterSunset: Bool) -> HDay {
        let local = Calendar.current.dateComponents([.year, .month, .day], from: instant)
        let today = HDay(civilYear: local.year!, month: local.month!, day: local.day!)
        return afterSunset ? today.adding(1) : today
    }

    func adding(_ days: Int) -> HDay {
        HDay(noonUTC: civil.addingTimeInterval(Double(days) * 86_400))
    }

    var isLeapYear: Bool { (7 * year + 1) % 19 < 7 }
    var isShabbat: Bool { weekday == 7 }

    /// Length of the previous Hebrew month (29 or 30).
    var previousMonthLength: Int { adding(-day).day }

    /// Civil (Gregorian) year/month/day of this Hebrew day's daytime.
    var civilComponents: DateComponents {
        Self.gregCal.dateComponents([.year, .month, .day], from: civil)
    }

    func `is`(_ m: HMonth, _ d: Int) -> Bool { month == m && day == d }
    func `is`(_ m: HMonth, _ r: ClosedRange<Int>) -> Bool { month == m && r.contains(day) }
}

// MARK: - Molad

extension HDay {
    /// Month number in Dershowitz & Reingold's scheme (Nisan = 1 … Tishrei = 7).
    private var drMonth: Int {
        switch month {
        case .nisan: return 1
        case .iyar: return 2
        case .sivan: return 3
        case .tammuz: return 4
        case .av: return 5
        case .elul: return 6
        case .tishrei: return 7
        case .cheshvan: return 8
        case .kislev: return 9
        case .tevet: return 10
        case .shvat: return 11
        case .adar1: return 12
        case .adar: return isLeapYear ? 13 : 12
        }
    }

    /// Molad of this Hebrew month as the traditional clock time (Jerusalem
    /// mean time), expressed as a Date whose UTC fields equal that clock time.
    /// Formula from Dershowitz & Reingold, "Calendrical Calculations".
    var moladClock: Date {
        let y = drMonth < 7 ? year + 1 : year
        let monthsElapsed = Double(drMonth - 7) + floor(Double(235 * y - 234) / 19)
        let hebrewEpochRD = -1_373_427.0
        let rd = hebrewEpochRD - 876.0 / 25_920 + monthsElapsed * (29 + 0.5 + 793.0 / 25_920)
        return Date(timeIntervalSince1970: (rd - 719_163) * 86_400)
    }

    /// The molad as a real instant: Jerusalem mean time is UTC+2:20:56.
    var molad: Date { moladClock.addingTimeInterval(-(2 * 3600 + 20 * 60 + 56)) }
}
