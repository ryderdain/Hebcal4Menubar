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
    private let location = Location.munich
    private var lastDate: HebrewDate?
    private var cachedSunset: Date?
    private var sunsetValidFor: Date?       // start-of-day this sunset belongs to
    private var sunsetError: String?        // why the last sunset lookup failed
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
    @objc private func manualRefresh() { refresh() }
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
            let startOfDay = Calendar.current.startOfDay(for: today)
            if sunsetValidFor != startOfDay || cachedSunset == nil {
                do {
                    cachedSunset = try await HebcalClient.sunset(for: today, location: location)
                    sunsetError = cachedSunset == nil ? "no sunset in the response" : nil
                } catch {
                    cachedSunset = nil
                    sunsetError = error.localizedDescription
                }
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

        switch sunsetMode {
        case .auto:
            if let s = cachedSunset {
                let hhmm = Self.timeFormatter.string(from: s)
                let state = effectiveAfterSunset ? "after sunset → next day" : "before sunset"
                sunsetStatusItem.title = "Sunset \(hhmm) (\(state))"
            } else {
                let reason = sunsetError.map { ": \($0)" } ?? ""
                sunsetStatusItem.title = "Sunset time unavailable\(reason) (using civil day)"
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

        guard var index = menu.items.firstIndex(of: sunsetStatusItem) else { return }
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

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "H:mm"
        return f
    }()
}
