//
//  Zmanim.swift
//  Hebcal4Menubar
//
//  The day's zmanim and the next candle lighting / havdalah, from Hebcal.
//  Opinions (chosen for this app; see README "Zmanim"):
//    - latest Shema and Tefilla: both MGA (72 minutes) and GRA
//    - misheyakir: both 11.5° and 10.2° (machmir)
//    - tzeit hakochavim and havdalah: 8.5°
//    - candle lighting: 18 minutes before sunset
//

import Foundation

/// One line of the Zmanim submenu. A line has one or two Hebcal fields
/// (for example MGA and GRA); each field is also a separate "next zman".
struct ZmanLine {
    let title: String
    let fields: [(key: String, label: String?)]

    /// This line's times in one day's response.
    func times(in day: [String: Date]) -> [(time: Date, label: String?)] {
        fields.compactMap { f in day[f.key].map { ($0, f.label) } }
    }
}

enum Zmanim {
    /// Submenu order. Keys are fields of the Hebcal Zmanim API `times` object.
    /// Hebcal's `chatzotNight` for a date is the midnight at the START of
    /// that date (2026-09-29 → 2026-09-29T01:05), the first zman of the day.
    static let lines: [ZmanLine] = [
        ZmanLine(title: "Chatzot halayla", fields: [("chatzotNight", nil)]),
        ZmanLine(title: "Alot hashachar (16.1°)", fields: [("alotHaShachar", nil)]),
        ZmanLine(title: "Misheyakir", fields: [("misheyakir", "11.5°"), ("misheyakirMachmir", "10.2°")]),
        ZmanLine(title: "Sunrise", fields: [("sunrise", nil)]),
        ZmanLine(title: "Latest Shema", fields: [("sofZmanShmaMGA", "MGA"), ("sofZmanShma", "GRA")]),
        ZmanLine(title: "Latest Tefilla", fields: [("sofZmanTfillaMGA", "MGA"), ("sofZmanTfilla", "GRA")]),
        ZmanLine(title: "Chatzot", fields: [("chatzot", nil)]),
        ZmanLine(title: "Mincha gedola", fields: [("minchaGedola", nil)]),
        ZmanLine(title: "Mincha ketana", fields: [("minchaKetana", nil)]),
        ZmanLine(title: "Plag hamincha", fields: [("plagHaMincha", nil)]),
        ZmanLine(title: "Sunset", fields: [("sunset", nil)]),
        ZmanLine(title: "Tzeit hakochavim (8.5°)", fields: [("tzeit85deg", nil)]),
    ]

    /// Minutes before sunset for Shabbat and Yom Tov candle lighting.
    static let candleLightingMinutes = 18

    /// The next zman after `now`, searched in today's and tomorrow's times.
    static func next(after now: Date, in days: [[String: Date]]) -> (name: String, time: Date)? {
        var best: (String, Date)?
        for times in days {
            for line in lines {
                for f in line.fields {
                    guard let t = times[f.key], t > now else { continue }
                    let name = f.label.map { "\(line.title) (\($0))" } ?? line.title
                    if best == nil || t < best!.1 { best = (name, t) }
                }
            }
        }
        return best
    }

    /// "in 42 min", "in 2 h 5 min".
    static func relative(from now: Date, to t: Date) -> String {
        let minutes = max(0, Int((t.timeIntervalSince(now) / 60).rounded(.up)))
        if minutes < 60 { return "in \(minutes) min" }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "in \(h) h" : "in \(h) h \(m) min"
    }
}

/// A candle-lighting or havdalah time.
struct ShabbatEvent {
    enum Kind { case candles, havdalah }
    let kind: Kind
    let time: Date
}

extension HebcalClient {

    /// All zmanim of one civil date for a location, as exact instants.
    /// Hebcal returns ISO-8601 times with the location's UTC offset; the full
    /// timestamp is kept, so "chatzot halayla" after midnight sorts correctly.
    static func zmanim(for date: Date, location: Location) async throws -> [String: Date] {
        var comps = URLComponents(string: "https://www.hebcal.com/zmanim")!
        comps.queryItems = [
            URLQueryItem(name: "cfg", value: "json"),
            URLQueryItem(name: "date", value: isoDayString(date)),
        ] + location.queryItems
        guard let url = comps.url else { throw HebcalError.badURL }
        let resp = try await getJSON(url, as: ZmanimTimes.self)
        var out: [String: Date] = [:]
        for (k, v) in resp.times { if let d = isoInstant(v) { out[k] = d } }
        guard out["sunset"] != nil else { throw HebcalError.decoding }
        return out
    }

    /// The next chain of candle lightings that ends with a havdalah, starting
    /// after `now`. Major holidays must be on in the query: without them,
    /// Hebcal treats a Yom Tov after Shabbat as a weekday (wrong havdalah).
    static func nextShabbat(after now: Date, location: Location, israel: Bool) async throws -> [ShabbatEvent] {
        var comps = URLComponents(string: "https://www.hebcal.com/hebcal")!
        let start = now.addingTimeInterval(-86_400)          // include tonight's times
        let end = now.addingTimeInterval(16 * 86_400)
        comps.queryItems = [
            URLQueryItem(name: "v", value: "1"),
            URLQueryItem(name: "cfg", value: "json"),
            URLQueryItem(name: "start", value: isoDayString(start)),
            URLQueryItem(name: "end", value: isoDayString(end)),
            URLQueryItem(name: "c", value: "on"),
            URLQueryItem(name: "b", value: String(Zmanim.candleLightingMinutes)),
            URLQueryItem(name: "M", value: "on"),              // havdalah at tzeit 8.5°
            URLQueryItem(name: "maj", value: "on"),
            URLQueryItem(name: "i", value: israel ? "on" : "off"),
        ] + location.queryItems
        guard let url = comps.url else { throw HebcalError.badURL }
        let resp = try await getJSON(url, as: CalendarItems.self)

        var chain: [ShabbatEvent] = []
        for item in resp.items {
            let kind: ShabbatEvent.Kind
            switch item.category {
            case "candles": kind = .candles
            case "havdalah": kind = .havdalah
            default: continue
            }
            guard let t = isoInstant(item.date), t > now else { continue }
            chain.append(ShabbatEvent(kind: kind, time: t))
            if kind == .havdalah { break }
        }
        return chain
    }
}

private struct ZmanimTimes: Decodable { let times: [String: String] }
private struct CalendarItems: Decodable {
    struct Item: Decodable { let date: String; let category: String }
    let items: [Item]
}
