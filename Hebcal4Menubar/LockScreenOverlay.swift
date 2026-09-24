//
//  LockScreenOverlay.swift
//  Hebcal4Menubar
//
//  Shows the Hebrew date on the macOS lock screen.
//
//  macOS has no public API for this: there are no lock-screen widgets and no
//  "alternate calendar" option like iOS/iPadOS. The lock screen is drawn in a
//  SkyLight (window server) space at a very high absolute level, so a normal
//  window — even at the highest NSWindow.Level — sits underneath it.
//
//  The workaround used by lock-screen widget apps: create our own SkyLight
//  space, raise it to the level the system uses for Notification Center on
//  the lock screen, and move a borderless window into it. The private symbols
//  are resolved at runtime with dlsym; if any is missing (a future macOS
//  removed or renamed it) the overlay disables itself instead of crashing.
//
//  Technique adapted from SkyLightWindow by Lakr233 (MIT):
//  https://github.com/Lakr233/SkyLightWindow
//

import Cocoa

// MARK: - SkyLight bridge (private API)

private final class SkyLight {
    /// nil when SkyLight or one of its symbols can't be found.
    static let shared: SkyLight? = SkyLight()

    /// Absolute level of the space that holds Notification Center while the
    /// screen is locked (screen lock itself is 300).
    private static let levelAboveScreenLock: Int32 = 400

    private typealias FMainConnectionID = @convention(c) () -> Int32
    private typealias FSpaceCreate = @convention(c) (Int32, Int32, Int32) -> Int32
    private typealias FSpaceSetAbsoluteLevel = @convention(c) (Int32, Int32, Int32) -> Int32
    private typealias FShowSpaces = @convention(c) (Int32, CFArray) -> Int32
    private typealias FSpaceAddWindows = @convention(c) (Int32, Int32, CFArray, Int32) -> Int32

    private let connection: Int32
    private let space: Int32
    private let addWindows: FSpaceAddWindows

    private init?() {
        guard
            let h = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight", RTLD_NOW),
            let pMain = dlsym(h, "SLSMainConnectionID"),
            let pCreate = dlsym(h, "SLSSpaceCreate"),
            let pLevel = dlsym(h, "SLSSpaceSetAbsoluteLevel"),
            let pShow = dlsym(h, "SLSShowSpaces"),
            let pAdd = dlsym(h, "SLSSpaceAddWindowsAndRemoveFromSpaces")
        else { return nil }

        let mainConnectionID = unsafeBitCast(pMain, to: FMainConnectionID.self)
        let spaceCreate = unsafeBitCast(pCreate, to: FSpaceCreate.self)
        let setLevel = unsafeBitCast(pLevel, to: FSpaceSetAbsoluteLevel.self)
        let showSpaces = unsafeBitCast(pShow, to: FShowSpaces.self)
        addWindows = unsafeBitCast(pAdd, to: FSpaceAddWindows.self)

        connection = mainConnectionID()
        space = spaceCreate(connection, 1, 0)
        guard space != 0 else { return nil }
        _ = setLevel(connection, space, Self.levelAboveScreenLock)
        _ = showSpaces(connection, [space] as CFArray)
    }

    /// Move a window into the high-level space.
    func adopt(_ window: NSWindow) {
        _ = addWindows(connection, space, [window.windowNumber] as CFArray, 7)
    }
}
// MARK: - Text views

/// How the date is drawn on the lock screen.
enum LockScreenStyle: String {
    case glass   // blurred backdrop cut to the glyphs + translucent white fill
    case plain   // solid white with a soft shadow
}

/// Draws one centred line of text. Used both for the visible fill and to
/// render the mask image, so the two always line up exactly.
private final class TextLineView: NSView {
    var attributed = NSAttributedString() { didSet { needsDisplay = true } }
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        Self.draw(attributed, in: bounds)
    }

    static func draw(_ s: NSAttributedString, in rect: NSRect) {
        let size = s.size()
        let origin = NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2)
        s.draw(at: origin)
    }
}

// MARK: - Overlay

/// Where the date sits on the lock screen.
enum LockScreenPosition: String {
    case aboveDate    // just above the native Gregorian date, over the clock
    case bottom       // above the user picture / password field area
}

final class LockScreenOverlay {

    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Keys.enabled); updateVisibility() }
    }
    var position: LockScreenPosition {
        didSet { UserDefaults.standard.set(position.rawValue, forKey: Keys.position); layout() }
    }
    var style: LockScreenStyle {
        didSet { UserDefaults.standard.set(style.rawValue, forKey: Keys.style); applyStyle() }
    }
    /// True when the private API resolved and the overlay can work at all.
    var isSupported: Bool { skyLight != nil }

    private enum Keys {
        static let enabled = "lockScreenEnabled"
        static let position = "lockScreenPosition"
        static let style = "lockScreenStyle"
        /// Optional fine-tuning in points; positive moves the date up.
        /// `defaults write com.example.Hebcal4Menubar lockScreenNudge -float 6`
        static let nudge = "lockScreenNudge"
        /// Optional override of the glass fill opacity (0…1).
        static let glassAlpha = "lockScreenGlassAlpha"
    }

    private let font = NSFont.systemFont(ofSize: 24, weight: .semibold)
    /// The native date lifts each colour channel of the wallpaper by about
    /// the same amount (~130/255) — an additive blend. With the plusL fill
    /// over the dark blur, 0.56 matched it in side-by-side captures.
    private var glassAlpha: CGFloat {
        let v = UserDefaults.standard.double(forKey: Keys.glassAlpha)
        return v > 0 ? CGFloat(v) : 0.56
    }

    private let skyLight = SkyLight.shared
    private var window: NSWindow?
    private var text = ""
    private let effect = NSVisualEffectView()
    private let fill = TextLineView()
    private var isLocked = false

    init() {
        let d = UserDefaults.standard
        isEnabled = d.object(forKey: Keys.enabled) as? Bool ?? true
        position = LockScreenPosition(rawValue: d.string(forKey: Keys.position) ?? "") ?? .aboveDate
        style = LockScreenStyle(rawValue: d.string(forKey: Keys.style) ?? "") ?? .glass

        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(self, selector: #selector(screenLocked),
                        name: .init("com.apple.screenIsLocked"), object: nil)
        dnc.addObserver(self, selector: #selector(screenUnlocked),
                        name: .init("com.apple.screenIsUnlocked"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
                                               name: NSApplication.didChangeScreenParametersNotification,
                                               object: nil)

        isLocked = Self.sessionIsLocked()
        if isSupported { buildWindow() }
        updateVisibility()
    }

    /// Set the text shown on the lock screen.
    func setText(_ text: String) {
        self.text = text
        applyStyle()
    }

    // MARK: Lock state

    @objc private func screenLocked() { isLocked = true; updateVisibility() }
    @objc private func screenUnlocked() { isLocked = false; updateVisibility() }
    @objc private func screensChanged() { layout() }

    private static func sessionIsLocked() -> Bool {
        guard let dict = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return (dict["CGSSessionScreenIsLocked"] as? Bool) ?? false
    }

    // MARK: Window

    private func buildWindow() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 60),
                         styleMask: [.borderless], backing: .buffered, defer: false)
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = false
        w.ignoresMouseEvents = true
        w.canBecomeVisibleWithoutLogin = true
        w.isReleasedWhenClosed = false
        w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        w.level = NSWindow.Level(rawValue: Int(Int32.max - 2))
        w.alphaValue = 0

        let content = NSView(frame: w.contentRect(forFrameRect: w.frame))
        content.wantsLayer = true

        // Layer 1: blurred wallpaper, masked to the glyph shapes. The dark
        // HUD material keeps the wallpaper's own colour; light materials
        // wash it out to grey.
        effect.frame = content.bounds
        effect.autoresizingMask = [.width, .height]
        effect.blendingMode = .behindWindow
        effect.material = .hudWindow
        effect.state = .active
        effect.appearance = NSAppearance(named: .vibrantDark)
        content.addSubview(effect)

        // Layer 2: white fill, added ("plus lighter") onto the blur so the
        // letters brighten whatever colour is behind them, like the native
        // date. "plusL" is Core Animation's undocumented name for that
        // blend; if it is ever ignored, the fill falls back to a normal
        // translucent overlay, which still looks acceptable.
        fill.frame = content.bounds
        fill.autoresizingMask = [.width, .height]
        fill.wantsLayer = true
        content.addSubview(fill)

        w.contentView = content

        // Must be on screen (have a window number) before it can move spaces.
        w.orderFrontRegardless()
        skyLight?.adopt(w)
        window = w
        applyStyle()
    }

    private func attributed(color: NSColor, shadow: NSShadow? = nil) -> NSAttributedString {
        var attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        if let shadow { attrs[.shadow] = shadow }
        return NSAttributedString(string: text, attributes: attrs)
    }

    private func applyStyle() {
        guard window != nil else { return }
        switch style {
        case .glass:
            fill.attributed = attributed(color: NSColor.white.withAlphaComponent(glassAlpha))
            fill.layer?.compositingFilter = "plusL"
            effect.isHidden = false
        case .plain:
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
            shadow.shadowBlurRadius = 6
            shadow.shadowOffset = NSSize(width: 0, height: -1)
            fill.attributed = attributed(color: .white, shadow: shadow)
            fill.layer?.compositingFilter = nil
            effect.isHidden = true
        }
        layout()
    }

    /// Rebuild the effect view's mask so the blur shows only inside the glyphs.
    private func updateMask(size: NSSize) {
        let s = attributed(color: .black)
        effect.maskImage = NSImage(size: size, flipped: true) { rect in
            TextLineView.draw(s, in: rect)
            return true
        }
    }

    private func layout() {
        // The lock-screen clock and date are drawn on the primary display
        // (the one with the menubar), which is always screens[0].
        guard let w = window, let screen = NSScreen.screens.first else { return }
        let f = screen.frame
        let textSize = attributed(color: .white).size()
        let width = min(f.width - 40, max(300, ceil(textSize.width) + 40))
        let height = ceil(textSize.height) + 4  // window hugs the text line
        let x = f.midX - width / 2
        let nudge = CGFloat(UserDefaults.standard.double(forKey: Keys.nudge))
        let y: CGFloat
        switch position {
        case .aboveDate:
            // Measured on macOS 27 (3440×1440): the top of the native date's
            // capitals sits 9.6 % of the screen height below the top edge.
            let nativeDateTop = f.maxY - f.height * 0.096
            y = nativeDateTop + 6               // small gap above it
        case .bottom:
            y = f.minY + f.height * 0.22        // above the login controls
        }
        w.setFrame(NSRect(x: x, y: y + nudge, width: width, height: height), display: true)
        if style == .glass { updateMask(size: NSSize(width: width, height: height)) }
    }

    private func updateVisibility() {
        guard let w = window else { return }
        let show = isEnabled && isLocked
        if show {
            layout()
            w.orderFrontRegardless()
            skyLight?.adopt(w)   // re-adopt in case the window server dropped it
        }
        w.alphaValue = show ? 1 : 0
    }
}
