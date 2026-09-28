//
//  HebcalClient.swift
//  HebrewDateMenubar
//
//  Talks to the Hebcal.com REST APIs:
//    - Converter: https://www.hebcal.com/home/219/hebrew-date-converter-rest-api
//    - Zmanim:    https://www.hebcal.com/home/1663/zmanim-halachic-times-api
//  Content from these APIs is CC-BY 4.0; attribution is shown in the menu.
//

import Foundation

// MARK: - Models

/// A decoded Gregorian→Hebrew conversion result.
struct HebrewDate: Decodable {
    let hy: Int          // Hebrew year
    let hm: String       // Hebrew month (transliterated, e.g. "Iyyar")
    let hd: Int          // Hebrew day of month
    let hebrew: String   // fully-pointed Hebrew string
    let events: [String]?

    var transliterated: String { "\(hd) \(hm) \(hy)" }
}

enum HebcalError: Error, LocalizedError {
    case badURL
    case http(Int)
    case transport(String)
    case decoding

    var errorDescription: String? {
        switch self {
        case .badURL:           return "Bad URL"
        case .http(let code):   return "HTTP \(code)"
        case .transport(let m): return "Network: \(m)"
        case .decoding:         return "Bad response"
        }
    }
}

// MARK: - Client

/// A small async wrapper around the two Hebcal endpoints we use.
struct HebcalClient {
    static let userAgent = "HebrewDateMenubar/1.0 (+https://www.hebcal.com)"

    private static func get<T: Decodable>(_ url: URL, as type: T.Type) async throws -> T {
        var req = URLRequest(url: url)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 10

        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch {
            throw HebcalError.transport(error.localizedDescription)
        }
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw HebcalError.http(http.statusCode)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw HebcalError.decoding
        }
    }

    /// Convert a Gregorian date (yyyy-MM-dd) to its Hebrew equivalent.
    static func hebrewDate(for date: Date, afterSunset: Bool) async throws -> HebrewDate {
        var comps = URLComponents(string: "https://www.hebcal.com/converter")!
        var items = [
            URLQueryItem(name: "cfg", value: "json"),
            URLQueryItem(name: "g2h", value: "1"),
            URLQueryItem(name: "strict", value: "1"),
            URLQueryItem(name: "date", value: isoDay.string(from: date)),
        ]
        if afterSunset { items.append(URLQueryItem(name: "gs", value: "on")) }
        comps.queryItems = items
        guard let url = comps.url else { throw HebcalError.badURL }
        return try await get(url, as: HebrewDate.self)
    }

    /// Fetch today's sunset for a location. Returns nil if unavailable.
    static func sunset(for date: Date, location: Location) async throws -> Date? {
        var comps = URLComponents(string: "https://www.hebcal.com/zmanim")!
        var items = [
            URLQueryItem(name: "cfg", value: "json"),
            URLQueryItem(name: "date", value: isoDay.string(from: date)),
        ]
        items.append(contentsOf: location.queryItems)
        comps.queryItems = items
        guard let url = comps.url else { throw HebcalError.badURL }

        let resp = try await get(url, as: ZmanimResponse.self)
        guard let iso = resp.times.sunset else { return nil }
        // ISO-8601 with timezone offset, e.g. 2021-03-23T18:14:00-03:00
        return isoOffset.date(from: iso)
    }

    /// Daily learning schedules for one civil date.
    static func learning(for date: Date, israel: Bool) async throws -> [LearningItem] {
        var comps = URLComponents(string: "https://www.hebcal.com/hebcal")!
        let day = isoDay.string(from: date)
        comps.queryItems = [
            URLQueryItem(name: "v", value: "1"),
            URLQueryItem(name: "cfg", value: "json"),
            URLQueryItem(name: "start", value: day),
            URLQueryItem(name: "end", value: day),
            URLQueryItem(name: "i", value: israel ? "on" : "off"),
            URLQueryItem(name: "F", value: "on"),       // Daf Yomi
            URLQueryItem(name: "myomi", value: "on"),   // Mishnah Yomi
            URLQueryItem(name: "yyomi", value: "on"),   // Yerushalmi Yomi
            URLQueryItem(name: "nyomi", value: "on"),   // Nach Yomi
        ]
        guard let url = comps.url else { throw HebcalError.badURL }
        return try await get(url, as: LearningResponse.self).items
            .compactMap { item in LearningKind(rawValue: item.category).map { (item, $0) } }
            .map { item, kind in
                LearningItem(kind: kind, title: item.title, hebrew: item.hebrew,
                             link: item.link.flatMap(URL.init(string:)))
            }
    }

    /// The Torah reading for one civil date, if there is one.
    static func leyning(for date: Date, israel: Bool) async throws -> Leyning? {
        var comps = URLComponents(string: "https://www.hebcal.com/leyning")!
        comps.queryItems = [
            URLQueryItem(name: "cfg", value: "json"),
            URLQueryItem(name: "date", value: isoDay.string(from: date)),
            URLQueryItem(name: "i", value: israel ? "on" : "off"),
        ]
        guard let url = comps.url else { throw HebcalError.badURL }
        let resp = try await get(url, as: LeyningResponse.self)
        guard let first = resp.items.first, let summary = first.summary else { return nil }
        return Leyning(name: first.name.en, summary: summary)
    }

    // MARK: Date formatters

    private static let isoDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let isoOffset: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}

/// Minimal decode of the Zmanim response — we only need `sunset`.
private struct ZmanimResponse: Decodable {
    struct Times: Decodable { let sunset: String? }
    let times: Times
}

// MARK: - Learning and leyning

/// The learning schedules the menu can show, keyed by Hebcal's category.
enum LearningKind: String, CaseIterable {
    case dafyomi, mishnayomi, yerushalmi, nachyomi

    var title: String {
        switch self {
        case .dafyomi:    return "Daf Yomi"
        case .mishnayomi: return "Mishnah Yomi"
        case .yerushalmi: return "Yerushalmi Yomi"
        case .nachyomi:   return "Nach Yomi"
        }
    }
}

struct LearningItem {
    let kind: LearningKind
    let title: String
    let hebrew: String?
    let link: URL?
}

struct Leyning {
    let name: String
    let summary: String
}

private struct LearningResponse: Decodable {
    struct Item: Decodable {
        let title: String
        let category: String
        let hebrew: String?
        let link: String?
    }
    let items: [Item]
}

private struct LeyningResponse: Decodable {
    struct Item: Decodable {
        struct Name: Decodable { let en: String }
        let name: Name
        let summary: String?
    }
    let items: [Item]
}

// MARK: - Location

/// Location used only to compute sunset. Defaults to Munich.
struct Location {
    var latitude: Double
    var longitude: Double
    /// IANA time zone of the location. The Zmanim API rejects latitude and
    /// longitude without it (HTTP 400 "Timezone required"). This is the
    /// location's zone, not the Mac's: the two differ when you travel.
    var tzid: String

    static let munich = Location(latitude: 48.1374, longitude: 11.5755, tzid: "Europe/Berlin")

    var queryItems: [URLQueryItem] {
        [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "tzid", value: tzid),
        ]
    }
}
