//
//  AppDelegate.swift
//  HebrewDateMenubar
//
//  Builds the NSStatusItem (menubar item) and its menu, drives refreshes,
//  and implements genuine sunset awareness using the Zmanim sunset time.
//

import Cocoa

enum MenubarStyle: String { case translit, hebrew }
enum SunsetMode: String { case auto, on, off }

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private let menu = NSMenu()

    // Menu items we update in place
    private let hebrewItem = NSMenuItem(title: "…", action: nil, keyEquivalent: "")
    private let gregorianItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let eventsItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let sunsetStatusItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")

    private var styleTranslit: NSMenuItem!
    private var styleHebrew: NSMenuItem!
    private var modeAuto: NSMenuItem!
    private var modeOn: NSMenuItem!
    private var modeOff: NSMenuItem!

    // State
    private var style: MenubarStyle = .translit
    private var sunsetMode: SunsetMode = .auto
    private let location = Location.munich
    private var lastDate: HebrewDate?
    private var cachedSunset: Date?
    private var sunsetValidFor: Date?       // start-of-day this sunset belongs to
    private var effectiveAfterSunset = false
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "…"

        buildMenu()
        statusItem.menu = menu

        refresh()
        // Every 2 minutes: cheap, and reliably catches both the midnight
        // rollover and the sunset crossing.
        timer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    // MARK: - Menu construction

    private func buildMenu() {
        menu.addItem(hebrewItem)
        menu.addItem(gregorianItem)
        menu.addItem(.separator())
        menu.addItem(eventsItem)
        menu.addItem(sunsetStatusItem)
        menu.addItem(.separator())

        // Menubar style submenu
        let styleMenu = NSMenu()
        styleTranslit = NSMenuItem(title: "Transliterated (29 Iyyar 5771)",
                                   action: #selector(setStyleTranslit), keyEquivalent: "")
        styleHebrew = NSMenuItem(title: "Hebrew letters (כ״ט בְּאִיָיר…)",
                                 action: #selector(setStyleHebrew), keyEquivalent: "")
        styleTranslit.target = self
        styleHebrew.target = self
        styleMenu.addItem(styleTranslit)
        styleMenu.addItem(styleHebrew)
        let styleParent = NSMenuItem(title: "Menubar style", action: nil, keyEquivalent: "")
        styleParent.submenu = styleMenu
        menu.addItem(styleParent)

        // Sunset mode submenu
        let sunsetMenu = NSMenu()
        modeAuto = NSMenuItem(title: "Auto (at local sunset)",
                              action: #selector(setModeAuto), keyEquivalent: "")
        modeOn = NSMenuItem(title: "Always after sunset",
                            action: #selector(setModeOn), keyEquivalent: "")
        modeOff = NSMenuItem(title: "Never (civil day)",
                             action: #selector(setModeOff), keyEquivalent: "")
        [modeAuto, modeOn, modeOff].forEach { $0?.target = self; sunsetMenu.addItem($0!) }
        let sunsetParent = NSMenuItem(title: "Sunset mode", action: nil, keyEquivalent: "")
        sunsetParent.submenu = sunsetMenu
        menu.addItem(sunsetParent)

        let refreshItem = NSMenuItem(title: "Refresh now",
                                     action: #selector(manualRefresh), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(.separator())

        let attribution = NSMenuItem(title: "Dates by Hebcal.com",
                                     action: #selector(openHebcal), keyEquivalent: "")
        attribution.target = self
        menu.addItem(attribution)

        let quit = NSMenuItem(title: "Quit", action: #selector(NSApp.terminate(_:)),
                              keyEquivalent: "q")
        menu.addItem(quit)

        syncCheckmarks()
    }

    private func syncCheckmarks() {
        styleTranslit.state = style == .translit ? .on : .off
        styleHebrew.state = style == .hebrew ? .on : .off
        modeAuto.state = sunsetMode == .auto ? .on : .off
        modeOn.state = sunsetMode == .on ? .on : .off
        modeOff.state = sunsetMode == .off ? .on : .off
    }

    // MARK: - Actions

    @objc private func setStyleTranslit() { style = .translit; syncCheckmarks(); rerender() }
    @objc private func setStyleHebrew()   { style = .hebrew;   syncCheckmarks(); rerender() }
    @objc private func setModeAuto() { sunsetMode = .auto; syncCheckmarks(); refresh() }
    @objc private func setModeOn()   { sunsetMode = .on;   syncCheckmarks(); refresh() }
    @objc private func setModeOff()  { sunsetMode = .off;  syncCheckmarks(); refresh() }
    @objc private func manualRefresh() { refresh() }
    @objc private func openHebcal() {
        if let url = URL(string: "https://www.hebcal.com/converter") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Sunset resolution

    /// Decide whether to advance to the next Hebrew day right now.
    private func resolveAfterSunset(today: Date) async -> Bool {
        switch sunsetMode {
        case .on:  return true
        case .off: return false
        case .auto:
            let startOfDay = Calendar.current.startOfDay(for: today)
            if sunsetValidFor != startOfDay || cachedSunset == nil {
                cachedSunset = try? await HebcalClient.sunset(for: today, location: location)
                sunsetValidFor = startOfDay
            }
            guard let sunset = cachedSunset else { return false } // fail safe
            return Date() >= sunset
        }
    }

    // MARK: - Refresh

    private func refresh() {
        Task { await refreshAsync() }
    }

    @MainActor
    private func refreshAsync() async {
        let today = Date()
        let afterSunset = await resolveAfterSunset(today: today)
        effectiveAfterSunset = afterSunset
        do {
            let data = try await HebcalClient.hebrewDate(for: today, afterSunset: afterSunset)
            lastDate = data
            render(data)
        } catch {
            renderError(error.localizedDescription)
        }
    }

    // MARK: - Rendering

    private func title(for d: HebrewDate) -> String {
        style == .hebrew ? d.hebrew : d.transliterated
    }

    private func rerender() { if let d = lastDate { render(d) } }

    private func render(_ d: HebrewDate) {
        statusItem.button?.title = title(for: d)
        hebrewItem.title = d.hebrew
        gregorianItem.title = Self.gregorianFormatter.string(from: Date())

        if let events = d.events, !events.isEmpty {
            eventsItem.title = events.joined(separator: "  •  ")
        } else {
            eventsItem.title = "No events today"
        }

        switch sunsetMode {
        case .auto:
            if let s = cachedSunset {
                let hhmm = Self.timeFormatter.string(from: s)
                let state = effectiveAfterSunset ? "after sunset → next day" : "before sunset"
                sunsetStatusItem.title = "Sunset \(hhmm) (\(state))"
            } else {
                sunsetStatusItem.title = "Sunset time unavailable (using civil day)"
            }
        case .on:  sunsetStatusItem.title = "Mode: always after sunset"
        case .off: sunsetStatusItem.title = "Mode: civil day"
        }
    }

    private func renderError(_ msg: String) {
        if let d = lastDate {
            statusItem.button?.title = title(for: d) + " ⚠"
            eventsItem.title = "Offline — last update shown (\(msg))"
        } else {
            statusItem.button?.title = "Hebrew Date ⚠"
            hebrewItem.title = "Couldn't reach Hebcal"
            gregorianItem.title = msg
            eventsItem.title = "Will retry automatically"
        }
    }

    // MARK: - Formatters

    private static let gregorianFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .full
        f.timeStyle = .none
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "H:mm"
        return f
    }()
}
