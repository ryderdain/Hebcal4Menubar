# Building the Swift Version in Xcode

This walks you through creating a native macOS menubar app from the four Swift
source files in `Hebcal4Menubar/`. No prior Xcode experience assumed.

The app has no window and no Dock icon — it lives entirely in the menubar. That
"agent" behavior comes from one Info.plist key (`LSUIElement`), explained below.

---

## Option A — Xcode project (recommended for learning)

### 1. Create the project

1. Open **Xcode** → **File → New → Project…**
2. Choose **macOS → App**, click **Next**.
3. Fill in:
   - **Product Name:** `Hebcal4Menubar`
   - **Interface:** **AppKit** (⚠️ not SwiftUI — this app is AppKit-based)
   - **Language:** **Swift**
   - Uncheck **Use Core Data** and **Include Tests** (not needed).
4. Pick a folder and click **Create**.

Xcode generates a starter app with an `AppDelegate.swift`, a
`ViewController.swift`, a `Main.storyboard`, and an `Info.plist`-equivalent in
build settings. We're going to strip it down to a pure menubar app.

### 2. Remove the window/storyboard scaffolding

A menubar app has no window, so delete the GUI scaffolding Xcode made:

1. In the Project Navigator (left sidebar), select and **delete**
   (Move to Trash): `Main.storyboard` and `ViewController.swift`.
2. Select the project at the top of the navigator → your **target** →
   **Info** tab. Find **"Main storyboard file base name"** (key
   `NSMainStoryboardFile`) and **remove that row** (click the `–`). If you
   don't, the app crashes on launch looking for the storyboard you deleted.

### 3. Add the source files

1. Delete Xcode's generated `AppDelegate.swift` (we have our own).
2. **File → Add Files to "Hebcal4Menubar"…**, then add all four:
   - `main.swift`
   - `AppDelegate.swift`
   - `HebcalClient.swift`
   - (you do not need to add `Info.plist` as a source file — see step 4)
3. Make sure **"Copy items if needed"** is checked and the **target** box is
   ticked so they're compiled.

> **Why `main.swift` instead of `@main`?** When a file is literally named
> `main.swift`, Swift treats its top-level code as the program entry point.
> That's why `main.swift` can just call `app.run()` directly. If you'd rather
> use the `@main` attribute on `AppDelegate` with
> `@NSApplicationMain`-style setup, you can — but the `main.swift` approach is
> explicit and also compiles from the command line (Option B).

### 4. Set the `LSUIElement` key (hides the Dock icon)

This is the single most important setting for a menubar-only app.

1. Select the project → target → **Info** tab.
2. Hover any row, click **`+`**, and add:
   - **Key:** `Application is agent (UIElement)`
     (its raw name is `LSUIElement`)
   - **Type:** `Boolean`
   - **Value:** `YES`

With this set, launching the app shows **no Dock icon and no app switcher
entry** — only your menubar item. (The provided `Info.plist` already contains
this key if you prefer to point the target's Info.plist setting at that file
instead.)

### 5. Allow network requests (App Sandbox)

New Xcode apps enable the **App Sandbox**, which blocks outgoing network by
default. To let the app reach hebcal.com:

1. Select the target → **Signing & Capabilities**.
2. Under **App Sandbox**, check **Outgoing Connections (Client)**.
   (If you don't see App Sandbox, the app will still make network calls fine;
   the sandbox is only a restriction when present.)

### 6. Run

Press **⌘R**. The Hebrew date appears in your menubar. Click it for the full
menu: Hebrew-letters form, Gregorian date, today's events, the **Menubar
style** and **Sunset mode** submenus, refresh, and Hebcal attribution.

---

## Option B — Build from the command line (fastest, no project file)

If you just want a running `.app` without clicking through Xcode, you need the
Xcode command-line tools (`xcode-select --install`). Then from inside the
`Hebcal4Menubar/` folder:

```bash
# Compile the three sources into one binary
swiftc -O \
  Hebcal4Menubar/main.swift \
  Hebcal4Menubar/AppDelegate.swift \
  Hebcal4Menubar/HebcalClient.swift \
  -o Hebcal4Menubar.bin

# Assemble a minimal .app bundle
APP=Hebcal4Menubar.app
mkdir -p "$APP/Contents/MacOS"
cp Hebcal4Menubar.bin "$APP/Contents/MacOS/Hebcal4Menubar"
cp Hebcal4Menubar/Info.plist "$APP/Contents/Info.plist"

# Launch it
open "$APP"
```

Because the bundled `Info.plist` already sets `LSUIElement`, the launched app
is menubar-only. To stop it, use the **Quit** item in its menu (or
`killall Hebcal4Menubar`).

> Command-line builds are unsigned. macOS may warn on first launch
> (right-click → Open to bypass Gatekeeper once). For a signed, distributable
> app, use the Xcode project in Option A and set your signing team.

---

## Run at login

Either build path produces a normal `.app`. To start it automatically:

**System Settings → General → Login Items → Open at Login → `+`**, then select
`Hebcal4Menubar.app`.

---

## Changing your location

Sunset is computed for a location (default: Munich). Edit `Location.munich` in
`HebcalClient.swift`:

```swift
static let munich = Location(latitude: 40.7128, longitude: -74.0060) // NYC
```

The Zmanim API also accepts a GeoNames ID or US ZIP; you'd extend `Location`
and its `queryItems` to emit `geonameid=` or `zip=` instead of lat/long. See
the location notes at https://www.hebcal.com/home/4912.
