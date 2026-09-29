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

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private var statusItem: NSStatusItem!
    private let menu = NSMenu()

    // Menu items we update in place
    private let hebrewItem = NSMenuItem(title: "…", action: nil, keyEquivalent: "")
    private let gregorianItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let eventsItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let sunsetStatusItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let nextZmanItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let candlesItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let havdalahItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let zmanimParentItem = NSMenuItem(title: "Zmanim", action: nil, keyEquivalent: "")
    private let zmanimMenu = NSMenu()

    private var styleTranslit: NSMenuItem!
    private var styleHebrew: NSMenuItem!
    private var modeAuto: NSMenuItem!
    private var modeOn: NSMenuItem!
    private var modeOff: NSMenuItem!
    private var lockShow: NSMenuItem!
    private var lockAboveDate: NSMenuItem!
    private var lockBottom: NSMenuItem!
    private var lockGlass: NSMenuItem!
    private var lockPlain: NSMenuItem!

    private var lockOverlay: LockScreenOverlay!

    // Learning + davening (inline sections, rebuilt on every render)
    private var dynamicItems: [NSMenuItem] = []
    private var nusachItems: [Nusach: NSMenuItem] = [:]
    private var israelItem: NSMenuItem!
    private var learningToggleItems: [LearningKind: NSMenuItem] = [:]
    private var learning: [LearningItem] = []
    private var leyning: Leyning?
    private var learningFetchedFor: String?    // "yyyy-MM-dd|israel" of the cached data

    private var nusach: Nusach {
        get { Nusach(rawValue: UserDefaults.standard.string(forKey: "nusach") ?? "") ?? .ashkenaz }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "nusach") }
    }
    private var israel: Bool {
        get { UserDefaults.standard.bool(forKey: "israel") }
        set { UserDefaults.standard.set(newValue, forKey: "israel") }
    }
    private func isLearningShown(_ k: LearningKind) -> Bool {
        UserDefaults.standard.object(forKey: "learning.\(k.rawValue)") as? Bool ?? true
    }

    // State
    private var style: MenubarStyle = .translit
    private var sunsetMode: SunsetMode = .auto
    private let locationProvider = LocationProvider()
    private var lastDate: HebrewDate?
    private var cachedSunset: Date?
    private var sunsetValidFor: Date?       // start-of-day this sunset belongs to
    private var sunsetError: String?        // why the last sunset lookup failed
    private var sunsetPlaceKey: String?     // Place.cacheKey the cached sunset belongs to
    private var sunsetPlaceName = ""
    private var zmanimToday: [String: Date] = [:]
    private var zmanimTomorrow: [String: Date] = [:]
    private var zmanimDay: Date?             // civil day of zmanimToday
    private var zmanimTimeZone = TimeZone.current   // the place's zone
    private var shabbatEvents: [ShabbatEvent] = []
    private var shabbatKey: String?

    // Location submenu items we update in place
    private let locationStatusItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let fallbackInfoItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private var useCurrentItem: NSMenuItem!
    private var useElevationItem: NSMenuItem!
    private var openLocationSettingsItem: NSMenuItem!
    private var effectiveAfterSunset = false
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Show the calendar icon to the left of the date text. The image is
        // bundled as "MenubarIcon" (see make_icons.sh + Asset Catalog setup in
        // ICON_NOTES.md). If it's missing we just show text, so the app still
        // works before you've added the asset.
        if let button = statusItem.button {
            if let icon = NSImage(named: "MenubarIcon") {
                icon.size = NSSize(width: 18, height: 18)
                // Template mode lets macOS tint the icon for light/dark menu
                // bars automatically. Only looks right for a monochrome icon;
                // for a full-color icon, set this to false (see ICON_NOTES.md).
                icon.isTemplate = true
                button.image = icon
                button.imagePosition = .imageLeading
            }
            button.title = "…"
        }

        lockOverlay = LockScreenOverlay()

        locationProvider.onChange = { [weak self] in self?.locationChanged() }
        locationProvider.start()
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.locationProvider.refreshIfStale(maxAge: 0)
        }

        buildMenu()
        statusItem.menu = menu
        menu.delegate = self

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
        menu.addItem(nextZmanItem)
        menu.addItem(candlesItem)
        menu.addItem(havdalahItem)
        zmanimParentItem.submenu = zmanimMenu
        menu.addItem(zmanimParentItem)
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

        // Lock screen submenu
        let lockMenu = NSMenu()
        lockShow = NSMenuItem(title: "Show on lock screen",
                              action: #selector(toggleLockScreen), keyEquivalent: "")
        lockAboveDate = NSMenuItem(title: "Position: above date",
                                    action: #selector(setLockAboveDate), keyEquivalent: "")
        lockBottom = NSMenuItem(title: "Position: near bottom",
                                action: #selector(setLockBottom), keyEquivalent: "")
        lockGlass = NSMenuItem(title: "Style: glass (like the native date)",
                               action: #selector(setLockGlass), keyEquivalent: "")
        lockPlain = NSMenuItem(title: "Style: plain white",
                               action: #selector(setLockPlain), keyEquivalent: "")
        [lockShow, lockAboveDate, lockBottom, lockGlass, lockPlain].forEach { $0?.target = self }
        lockMenu.addItem(lockShow)
        lockMenu.addItem(.separator())
        lockMenu.addItem(lockAboveDate)
        lockMenu.addItem(lockBottom)
        lockMenu.addItem(.separator())
        lockMenu.addItem(lockGlass)
        lockMenu.addItem(lockPlain)
        let lockParent = NSMenuItem(title: "Lock screen", action: nil, keyEquivalent: "")
        lockParent.submenu = lockMenu
        if !lockOverlay.isSupported {
            lockParent.title = "Lock screen (unavailable on this macOS)"
            lockParent.isEnabled = false
        }
        menu.addItem(lockParent)

        // Davening settings: nusach + Israel/diaspora
        let daveningMenu = NSMenu()
        for n in Nusach.allCases {
            let item = NSMenuItem(title: n.title, action: #selector(setNusach(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = n.rawValue
            nusachItems[n] = item
            daveningMenu.addItem(item)
        }
        daveningMenu.addItem(.separator())
        israelItem = NSMenuItem(title: "Eretz Yisrael (Israel customs)",
                                action: #selector(toggleIsrael), keyEquivalent: "")
        israelItem.target = self
        daveningMenu.addItem(israelItem)
        let daveningParent = NSMenuItem(title: "Nusach", action: nil, keyEquivalent: "")
        daveningParent.submenu = daveningMenu
        menu.addItem(daveningParent)

        // Location for sunset: current location, with a fallback place
        let locationMenu = NSMenu()
        locationMenu.addItem(locationStatusItem)
        locationMenu.addItem(.separator())
        useCurrentItem = NSMenuItem(title: "Use current location",
                                    action: #selector(toggleUseCurrent), keyEquivalent: "")
        useCurrentItem.target = self
        locationMenu.addItem(useCurrentItem)
        useElevationItem = NSMenuItem(title: "Use elevation for sunset",
                                      action: #selector(toggleUseElevation), keyEquivalent: "")
        useElevationItem.target = self
        locationMenu.addItem(useElevationItem)
        locationMenu.addItem(.separator())
        locationMenu.addItem(fallbackInfoItem)
        let setFallback = NSMenuItem(title: "Set fallback location…",
                                     action: #selector(promptForFallback), keyEquivalent: "")
        setFallback.target = self
        locationMenu.addItem(setFallback)
        let resetFallback = NSMenuItem(title: "Reset fallback to Munich",
                                       action: #selector(resetFallback), keyEquivalent: "")
        resetFallback.target = self
        locationMenu.addItem(resetFallback)
        locationMenu.addItem(.separator())
        openLocationSettingsItem = NSMenuItem(title: "Open Location Services settings…",
                                              action: #selector(openLocationSettings), keyEquivalent: "")
        openLocationSettingsItem.target = self
        locationMenu.addItem(openLocationSettingsItem)
        let locationParent = NSMenuItem(title: "Location", action: nil, keyEquivalent: "")
        locationParent.submenu = locationMenu
        menu.addItem(locationParent)
        updateLocationItems()

        // Learning schedules shown
        let learningMenu = NSMenu()
        for k in LearningKind.allCases {
            let item = NSMenuItem(title: k.title, action: #selector(toggleLearning(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = k.rawValue
            learningToggleItems[k] = item
            learningMenu.addItem(item)
        }
        let learningParent = NSMenuItem(title: "Learning schedules", action: nil, keyEquivalent: "")
        learningParent.submenu = learningMenu
        menu.addItem(learningParent)

        let refreshItem = NSMenuItem(title: "Refresh now",
                                     action: #selector(manualRefresh), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(.separator())

        let attribution = NSMenuItem(title: "Dates by Hebcal.com",
                                     action: #selector(openHebcal), keyEquivalent: "")
        attribution.target = self
        menu.addItem(attribution)

        // Flaticon Free License attribution (visible spot).
        let iconCredit = NSMenuItem(title: "Icon: Freepik / Flaticon",
                                    action: #selector(openFlaticon), keyEquivalent: "")
        iconCredit.target = self
        menu.addItem(iconCredit)

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
        lockShow.state = lockOverlay.isEnabled ? .on : .off
        lockAboveDate.state = lockOverlay.position == .aboveDate ? .on : .off
        lockBottom.state = lockOverlay.position == .bottom ? .on : .off
        lockGlass.state = lockOverlay.style == .glass ? .on : .off
        lockPlain.state = lockOverlay.style == .plain ? .on : .off
        for (n, item) in nusachItems { item.state = n == nusach ? .on : .off }
        israelItem.state = israel ? .on : .off
        for (k, item) in learningToggleItems { item.state = isLearningShown(k) ? .on : .off }
    }

    // MARK: - Actions

    @objc private func setStyleTranslit() { style = .translit; syncCheckmarks(); rerender() }
    @objc private func setStyleHebrew()   { style = .hebrew;   syncCheckmarks(); rerender() }
    @objc private func setModeAuto() { sunsetMode = .auto; syncCheckmarks(); refresh() }
    @objc private func setModeOn()   { sunsetMode = .on;   syncCheckmarks(); refresh() }
    @objc private func setModeOff()  { sunsetMode = .off;  syncCheckmarks(); refresh() }
    @objc private func toggleLockScreen() { lockOverlay.isEnabled.toggle(); syncCheckmarks() }
    @objc private func setLockAboveDate() { lockOverlay.position = .aboveDate; syncCheckmarks() }
    @objc private func setLockBottom() { lockOverlay.position = .bottom; syncCheckmarks() }
    @objc private func setLockGlass() { lockOverlay.style = .glass; syncCheckmarks() }
    @objc private func setLockPlain() { lockOverlay.style = .plain; syncCheckmarks() }
    @objc private func setNusach(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let n = Nusach(rawValue: raw) { nusach = n }
        syncCheckmarks(); rerender()
    }
    @objc private func toggleIsrael() {
        israel.toggle(); learningFetchedFor = nil
        syncCheckmarks(); refresh()           // Israel changes the learning/leyning data too
    }
    @objc private func toggleLearning(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let k = LearningKind(rawValue: raw) else { return }
        UserDefaults.standard.set(!isLearningShown(k), forKey: "learning.\(k.rawValue)")
        syncCheckmarks(); rerender()
    }
    @objc private func openLink(_ sender: NSMenuItem) {
        if let url = sender.representedObject as? URL { NSWorkspace.shared.open(url) }
    }
    @objc private func toggleUseCurrent() { locationProvider.useCurrent.toggle() }
    @objc private func toggleUseElevation() { locationProvider.useElevation.toggle() }
    @objc private func resetFallback() { locationProvider.fallback = .munich }
    @objc private func openLocationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
            NSWorkspace.shared.open(url)
        }
    }
    @objc private func promptForFallback() { askForFallback(prefill: "") }
    @objc private func manualRefresh() { locationProvider.refreshIfStale(maxAge: 0); refresh() }
    @objc private func openHebcal() {
        if let url = URL(string: "https://www.hebcal.com/converter") {
            NSWorkspace.shared.open(url)
        }
    }
    @objc private func openFlaticon() {
        if let url = URL(string: "https://www.flaticon.com/free-icon/calendar_19034368") {
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
            guard let sunset = cachedSunset else { return false } // fail safe: civil day
            return Date() >= sunset
        }
    }

    // MARK: - Zmanim

    /// Key for everything that changes the zmanim: place, elevation setting.
    private var zmanimPlaceKey: String {
        locationProvider.effective.place.cacheKey + (locationProvider.useElevation ? "|elev" : "")
    }

    /// Fetch today's and tomorrow's zmanim once per civil day and place, and
    /// the next candle lighting / havdalah chain. Today's sunset drives Auto
    /// sunset mode. Failures keep what we had and are shown on the sunset line.
    @MainActor
    private func refreshZmanim(now: Date) async {
        let place = locationProvider.effective.place
        let useElevation = locationProvider.useElevation
        let location = place.location(useElevation: useElevation)
        let key = zmanimPlaceKey
        let startOfDay = Calendar.current.startOfDay(for: now)

        if sunsetValidFor != startOfDay || cachedSunset == nil || sunsetPlaceKey != key {
            do {
                let today = try await HebcalClient.zmanim(for: now, location: location)
                zmanimToday = today
                cachedSunset = today["sunset"]
                sunsetError = nil
                sunsetValidFor = startOfDay
                sunsetPlaceKey = key
                zmanimDay = startOfDay
                zmanimTimeZone = TimeZone(identifier: place.tzid) ?? .current
                sunsetPlaceName = place.name
                if useElevation, let e = place.elevation, e > 0 { sunsetPlaceName += ", \(Int(e.rounded())) m" }
                // Tomorrow: for "next zman" after tonight's last one. Best effort.
                let tomorrow = now.addingTimeInterval(86_400)
                zmanimTomorrow = (try? await HebcalClient.zmanim(for: tomorrow, location: location)) ?? [:]
            } catch {
                if sunsetPlaceKey != key { cachedSunset = nil; zmanimToday = [:]; zmanimTomorrow = [:] }
                sunsetError = error.localizedDescription
            }
        }

        let sKey = "\(key)|\(israel)"
        let stillAhead = shabbatEvents.contains { $0.time > now }
        if sKey != shabbatKey || !stillAhead {
            if let events = try? await HebcalClient.nextShabbat(after: now, location: location, israel: israel) {
                shabbatEvents = events
                shabbatKey = sKey
            }
        }
    }

    private func renderZmanim(now: Date) {
        let fmt = DateFormatter()
        fmt.timeZone = zmanimTimeZone
        fmt.dateFormat = "HH:mm"
        let dayFmt = DateFormatter()
        dayFmt.timeZone = zmanimTimeZone
        dayFmt.dateFormat = "EEE d MMM"
        let foreignZone = zmanimTimeZone.identifier != TimeZone.current.identifier
        let zoneNote = foreignZone ? " (\(zmanimTimeZone.abbreviation(for: now) ?? zmanimTimeZone.identifier))" : ""

        // Next zman, main menu.
        if let n = Zmanim.next(after: now, in: [zmanimToday, zmanimTomorrow]) {
            nextZmanItem.title = "Next: \(n.name) \(fmt.string(from: n.time))\(zoneNote) · \(Zmanim.relative(from: now, to: n.time))"
            nextZmanItem.isHidden = false
        } else {
            nextZmanItem.isHidden = true
        }

        // Candle lighting and havdalah, main menu.
        let candles = shabbatEvents.filter { $0.kind == .candles }
        let havdalah = shabbatEvents.first { $0.kind == .havdalah }
        let stamp = { (t: Date) in "\(dayFmt.string(from: t)) \(fmt.string(from: t))" }
        candlesItem.title = "Candle lighting: " + candles.map { stamp($0.time) }.joined(separator: " · ") + zoneNote
        candlesItem.isHidden = candles.isEmpty
        havdalahItem.title = "Havdalah: " + (havdalah.map { stamp($0.time) } ?? "") + zoneNote
        havdalahItem.isHidden = havdalah == nil

        // Zmanim submenu: today's list, with the next one marked.
        zmanimMenu.removeAllItems()
        guard !zmanimToday.isEmpty else {
            zmanimParentItem.isHidden = true
            return
        }
        zmanimParentItem.isHidden = false
        let nextTime = Zmanim.next(after: now, in: [zmanimToday, zmanimTomorrow])?.time
        let header = "\(sunsetPlaceName) · \(dayFmt.string(from: zmanimDay ?? now))\(zoneNote)"
        if #available(macOS 14.0, *) {
            zmanimMenu.addItem(NSMenuItem.sectionHeader(title: header))
        } else {
            let h = NSMenuItem(title: header, action: nil, keyEquivalent: ""); h.isEnabled = false
            zmanimMenu.addItem(h)
        }
        let mono = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        for line in Zmanim.lines {
            let times = line.times(today: zmanimToday, tomorrow: zmanimTomorrow)
            let parts = times.map { t in t.label.map { "\(fmt.string(from: t.time)) \($0)" } ?? fmt.string(from: t.time) }
            guard !parts.isEmpty else { continue }
            let isNext = times.contains { $0.time == nextTime }
            let text = "\(isNext ? "▸" : "  ") \(line.title): \(parts.joined(separator: " · "))"
            let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
            item.attributedTitle = NSAttributedString(string: text, attributes: [.font: mono])
            zmanimMenu.addItem(item)
        }
        zmanimMenu.addItem(.separator())
        let note = NSMenuItem(title: "Candle lighting \(Zmanim.candleLightingMinutes) min before sunset · havdalah at 8.5°",
                              action: nil, keyEquivalent: "")
        zmanimMenu.addItem(note)
    }

    // NSMenuDelegate: recompute "next" and "in N min" whenever the menu opens.
    func menuWillOpen(_ menu: NSMenu) {
        if menu === self.menu { renderZmanim(now: Date()) }
    }

    // MARK: - Refresh

    private func refresh() {
        Task { await refreshAsync() }
    }

    @MainActor
    private func refreshAsync() async {
        let today = Date()
        locationProvider.refreshIfStale()
        await refreshZmanim(now: today)
        let afterSunset = await resolveAfterSunset(today: today)
        effectiveAfterSunset = afterSunset
        do {
            let data = try await HebcalClient.hebrewDate(for: today, afterSunset: afterSunset)
            lastDate = data
            await refreshLearning()
            render(data)
        } catch {
            renderError(error.localizedDescription)
        }
    }

    /// Fetch learning and leyning once per displayed Hebrew day (and on an
    /// Israel/diaspora change). Failures keep the previous data.
    @MainActor
    private func refreshLearning() async {
        let civil = currentHebrewDay().civil
        let key = Self.dayKey.string(from: civil) + "|\(israel)"
        guard key != learningFetchedFor else { return }
        do {
            async let l = HebcalClient.learning(for: civil, israel: israel)
            async let r = HebcalClient.leyning(for: civil, israel: israel)
            learning = try await l
            leyning = try await r
            learningFetchedFor = key
        } catch {
            // Offline: keep what we have; the next refresh retries.
        }
    }

    private func currentHebrewDay() -> HDay {
        HDay.current(at: Date(), afterSunset: effectiveAfterSunset)
    }

    // MARK: - Rendering

    private func title(for d: HebrewDate) -> String {
        style == .hebrew ? d.hebrew : d.transliterated
    }

    private func rerender() { if let d = lastDate { render(d) } }

    private func render(_ d: HebrewDate) {
        statusItem.button?.title = title(for: d)
        lockOverlay.setText(title(for: d))
        hebrewItem.title = d.hebrew
        gregorianItem.title = Self.gregorianFormatter.string(from: Date())

        if let events = d.events, !events.isEmpty {
            eventsItem.title = events.joined(separator: "  •  ")
        } else {
            eventsItem.title = "No events today"
        }

        renderSections()

        if let s = cachedSunset {
            let fmt = DateFormatter()
            fmt.timeZone = zmanimTimeZone
            fmt.dateFormat = "HH:mm"
            let state: String
            switch sunsetMode {
            case .auto: state = effectiveAfterSunset ? "after sunset → next day" : "before sunset"
            case .on:   state = "mode: always after sunset"
            case .off:  state = "mode: civil day"
            }
            sunsetStatusItem.title = "Sunset \(fmt.string(from: s)) in \(sunsetPlaceName) (\(state))"
        } else {
            let reason = sunsetError.map { ": \($0)" } ?? ""
            sunsetStatusItem.title = "Sunset time unavailable\(reason) (using civil day)"
        }
        renderZmanim(now: Date())
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

    // MARK: - Location

    /// The effective place or the permission changed: update the submenu and,
    /// if the place is different, fetch the sunset for the new place.
    private func locationChanged() {
        updateLocationItems()
        if zmanimPlaceKey != sunsetPlaceKey { refresh() }
    }

    private func updateLocationItems() {
        guard useCurrentItem != nil else { return }
        locationStatusItem.title = locationProvider.statusLine
        useCurrentItem.state = locationProvider.useCurrent ? .on : .off
        useElevationItem.state = locationProvider.useElevation ? .on : .off
        let fb = locationProvider.fallback
        fallbackInfoItem.title = "Fallback: \(fb.name) (\(fb.tzid)\(fb.elevationText.map { ", " + $0 } ?? ""))"
        openLocationSettingsItem.isHidden = !locationProvider.needsSystemSettings
    }

    /// Ask for a fallback place. Accepts a city, "lat, lon" or "lat, lon, Area/City".
    private func askForFallback(prefill: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Set fallback location"
        alert.informativeText = "Used for sunset when the current location is not available.\n"
            + "Enter a city (for example Jerusalem), or coordinates as “lat, lon”, "
            + "optionally with a time zone and an elevation in metres: "
            + "“48.14, 11.58, Europe/Berlin, 524”."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.placeholderString = "City, or lat, lon[, Area/City[, metres]]"
        field.stringValue = prefill
        alert.accessoryView = field
        alert.addButton(withTitle: "Set")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let input = field.stringValue
        LocationProvider.resolve(input) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let place):
                    self?.locationProvider.fallback = place
                case .failure(let error):
                    let fail = NSAlert()
                    fail.messageText = "Could not set the fallback location"
                    fail.informativeText = error.localizedDescription
                    fail.addButton(withTitle: "Try Again")
                    fail.addButton(withTitle: "Cancel")
                    if fail.runModal() == .alertFirstButtonReturn { self?.askForFallback(prefill: input) }
                }
            }
        }
    }

    // MARK: - Learning and davening sections

    /// Rebuild the inline Learning and Davening sections under the sunset line.
    private func renderSections() {
        dynamicItems.forEach { menu.removeItem($0) }
        dynamicItems = []

        var items: [NSMenuItem] = []
        func header(_ title: String) -> NSMenuItem {
            if #available(macOS 14.0, *) { return NSMenuItem.sectionHeader(title: title) }
            let item = NSMenuItem(title: title.uppercased(), action: nil, keyEquivalent: "")
            item.isEnabled = false
            return item
        }
        func info(_ title: String) -> NSMenuItem {
            NSMenuItem(title: title, action: nil, keyEquivalent: "")
        }

        // Learning
        let shown = learning.filter { isLearningShown($0.kind) }
            .sorted { LearningKind.allCases.firstIndex(of: $0.kind)! < LearningKind.allCases.firstIndex(of: $1.kind)! }
        if !shown.isEmpty || leyning != nil {
            items.append(.separator())
            items.append(header("Learning"))
            for l in shown {
                let text = style == .hebrew ? (l.hebrew ?? l.title) : l.title
                let item = NSMenuItem(title: "\(l.kind.title): \(text)",
                                      action: l.link == nil ? nil : #selector(openLink(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = l.link
                items.append(item)
            }
            if let r = leyning { items.append(info("Torah reading: \(r.name) — \(r.summary)")) }
        }

        // Davening
        let h = currentHebrewDay()
        let notes = DaveningRules.notes(for: h, nusach: nusach, israel: israel,
                                        eveningStarted: effectiveAfterSunset)
        items.append(.separator())
        items.append(header("Davening · \(nusach.title) · \(israel ? "Israel" : "Diaspora")"))
        notes.forEach { items.append(info($0)) }

        guard var index = menu.items.firstIndex(of: zmanimParentItem) else { return }
        for item in items {
            index += 1
            menu.insertItem(item, at: index)
        }
        dynamicItems = items
    }

    private static let dayKey: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // MARK: - Formatters

    private static let gregorianFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .full
        f.timeStyle = .none
        return f
    }()

}
