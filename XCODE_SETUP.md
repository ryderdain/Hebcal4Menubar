# Building the Swift Version in Xcode

This walks you through creating a native macOS menubar app from the eight Swift
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
2. **File → Add Files to "Hebcal4Menubar"…**, then add all eight:
   - `main.swift`
   - `AppDelegate.swift`
   - `HebcalClient.swift`
   - `LockScreenOverlay.swift`
   - `HebrewDay.swift`
   - `DaveningRules.swift`
   - `LocationProvider.swift`
   - `Zmanim.swift`
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

## Option B — Build and install with `install.sh` (no project file)

`install.sh` builds the app and installs it in `/Applications`. When you start the script, it does not change your system. It only shows the commands that it will use. To use the commands, send them to `bash`.

Before you start, make sure that you have these items:

- The Xcode command-line tools (`xcode-select --install`).
- Bash 4.2 or higher (`brew install bash`). The Bash of macOS (`/bin/bash`) is version 3.2.

1. Go to the root folder of the repository.
2. Show the commands and examine them:

    ```bash
    bash install.sh
    ```

3. Build and install the app:

    ```bash
    bash install.sh | bash
    ```

The script does these steps:

- It compiles all Swift files in `Hebcal4Menubar/` into `build/`. Git ignores `build/`.
- It assembles `build/Hebcal4Menubar.app` and gives it an ad-hoc signature.
- If the app operates, it stops the app. It moves the copy that is in `/Applications` to the Trash.
- It copies the new app to `/Applications` and starts the app.

Other commands:

| Command | Result |
| --- | --- |
| `bash install.sh build_app \| bash` | Builds the app in `build/`. The script does not install the app. |
| `bash install.sh install_app \| bash` | Installs the last build. The script does not compile. |
| `INSTALL_DIR=~/Applications bash install.sh \| bash` | Installs the app in a different folder. |
| `CODESIGN_IDENTITY='Apple Development: …' bash install.sh \| bash` | Signs the app with a certificate. Then macOS keeps the Location Services permission after an update. |

If a step has an error, the steps after it do not start. The last line that starts with `==>` shows the step with the error. Correct the cause, then use the same command again.

The script gets the app name, the executable name and the icon from `Info.plist`. The script does not copy `MenubarIcon.png` or `MenubarIcon@2x.png` into the bundle. These files are full-color images. The app shows the menubar icon as a template image, thus macOS shows a full-color image as a solid white area. Refer to `ICON_NOTES.md`.

Because the bundled `Info.plist` already sets `LSUIElement`, the launched app
is menubar-only. To stop it, use the **Quit** item in its menu (or
`killall Hebcal4Menubar`).

> The `install.sh` build has only an ad-hoc signature. macOS can show a
> warning at the first launch (right-click → Open to bypass Gatekeeper one
> time). For a signed app that you can give to other persons, use the Xcode
> project in Option A and set your signing team.
>
> Tests of the lock screen date used only the `install.sh` build, which has
> no App Sandbox. The lock screen date uses a private framework. If you use
> the App Sandbox in Option A, make sure that the lock screen date operates.

---

## Run at login

Either build path produces a normal `.app`. To start it automatically:

**System Settings → General → Login Items → Open at Login → `+`**, then select
`Hebcal4Menubar.app`.

---

## Changing your location

The app uses the current location of the Mac. To change the fallback location, select **Location** > **Set fallback location…** in the menu (refer to "Location" in `README.md`). You do not have to change the code.

To change the default fallback location in the code, edit `Place.munich` in `LocationProvider.swift`:

```swift
static let munich = Place(name: "New York", latitude: 40.7128, longitude: -74.0060, tzid: "America/New_York", elevation: 10)
```

Set `tzid` to the time zone of the location, not to the time zone of your Mac. If there is no `tzid`, the Zmanim API does not give the sunset time (HTTP 400). The menu then shows "Sunset time unavailable".

If you use the App Sandbox in Option A, also select **Location** in the **App Data** section of **Signing & Capabilities**. Without this selection, the sandbox prevents access to Location Services, and the app always uses the fallback location.

The Zmanim API also accepts a GeoNames ID or US ZIP; you'd extend `Location`
and its `queryItems` to emit `geonameid=` or `zip=` instead of lat/long. See
the location notes at <https://www.hebcal.com/home/4912>.
