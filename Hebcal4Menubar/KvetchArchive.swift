//
//  KvetchArchive.swift
//  Hebcal4Menubar
//
//  "On this day" link for the Gregorian date line: the News Articles Archive
//  at kvetch-of-the-day.github.io. The archive is one static page, and its
//  search box does not read the URL, so the app downloads the page, finds the
//  article whose date (any year) is nearest to today's day of the year, and
//  links to the page with a text fragment (#:~:text=1936-09-29) that scrolls
//  to that article's date.
//

import Foundation

struct KvetchArticle: Equatable {
    let title: String
    let date: String      // yyyy-MM-dd
    let month: Int
    let day: Int
}

enum KvetchArchive {
    static let base = URL(string: "https://kvetch-of-the-day.github.io/news-articles-backup/")!

    /// Download the archive page and read its articles.
    static func fetch() async throws -> [KvetchArticle] {
        var req = URLRequest(url: base)
        req.timeoutInterval = 30
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200,
              let html = String(data: data, encoding: .utf8) else { throw HebcalError.decoding }
        return parse(html)
    }

    /// Cards look like:
    /// <article class="card" …><h2>Title</h2><div class="date">1936-09-04</div>
    static func parse(_ html: String) -> [KvetchArticle] {
        let pattern = #"<h2>(.*?)</h2>\s*<div class="date">(\d{4})-(\d{2})-(\d{2})</div>"#
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return [] }
        let ns = html as NSString
        return re.matches(in: html, range: NSRange(location: 0, length: ns.length)).compactMap { m in
            let s = { (i: Int) in ns.substring(with: m.range(at: i)) }
            guard let month = Int(s(3)), let day = Int(s(4)), (1...12).contains(month), (1...31).contains(day) else { return nil }
            return KvetchArticle(title: unescape(s(1)), date: "\(s(2))-\(s(3))-\(s(4))", month: month, day: day)
        }
    }

    /// Articles whose day of the year is nearest to `date`'s (the distance
    /// wraps around the new year). Several articles can share that day.
    static func nearest(to date: Date, in articles: [KvetchArticle], calendar: Calendar = .current) -> [KvetchArticle] {
        let c = calendar.dateComponents([.month, .day], from: date)
        guard let today = ordinal(month: c.month ?? 1, day: c.day ?? 1) else { return [] }
        let scored = articles.compactMap { a in
            ordinal(month: a.month, day: a.day).map { o -> (KvetchArticle, Int) in
                let d = abs(o - today)
                return (a, min(d, 366 - d))
            }
        }
        guard let best = scored.map(\.1).min() else { return [] }
        return scored.filter { $0.1 == best }.map(\.0)
    }

    /// Link that scrolls the archive page to `article`. In a text directive
    /// "-" is a separator, so it is percent-encoded.
    static func link(to article: KvetchArticle) -> URL {
        let text = article.date.replacingOccurrences(of: "-", with: "%2D")
        return URL(string: base.absoluteString + "#:~:text=" + text) ?? base
    }

    /// Day of the year in a leap year (Feb 29 included), 1…366.
    private static func ordinal(month: Int, day: Int) -> Int? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        guard let d = cal.date(from: DateComponents(year: 2000, month: month, day: day)),
              cal.component(.month, from: d) == month else { return nil }
        return cal.ordinality(of: .day, in: .year, for: d)
    }

    private static func unescape(_ s: String) -> String {
        s.replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}
