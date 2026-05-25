# Adding the Icon to the Swift App

You have `icon.png` (the full-color Flaticon calendar) in the app folder. This
covers turning it into the two kinds of icon a menubar app uses and wiring them
into Xcode.

## Step 0 — generate the assets

On your Mac, from the folder containing `icon.png`:

```bash
chmod +x make_icons.sh
./make_icons.sh
```

This uses the built-in `sips` and `iconutil` (no installs) to produce:

- `AppIcon.icns` — full-color app/bundle icon
- `MenubarIcon.png` + `MenubarIcon@2x.png` — small status-bar versions

## Step 1 — the app (bundle) icon

This is the colorful icon for Finder, Login Items, and the app switcher.

**In Xcode:** select `Assets.xcassets` → there's an **AppIcon** well. Drag
`icon.png` (ideally a 1024×1024) into the largest slot, or let Xcode fill all
sizes. Then in the target's **General → App Icons and Launch Screen**, make
sure **App Icon Source** is set to **AppIcon**.

(If you built from the command line instead, drop `AppIcon.icns` into
`HebrewDateMenubar.app/Contents/Resources/` and add `CFBundleIconFile` =
`AppIcon` to `Info.plist`.)

## Step 2 — the menubar icon (the important nuance)

The status bar is only ~18pt tall and supports light **and** dark menu bars.
There are two ways to go, and they look very different:

### Option A — template (monochrome) — recommended
A **template image** is a black-on-transparent silhouette. macOS automatically
tints it (dark in a light menu bar, light in a dark menu bar), so it always
looks native. `AppDelegate.swift` is already set up for this:
`icon.isTemplate = true`.

To make a template version: open `MenubarIcon.png` in Preview (or any editor)
and flatten the artwork to a single solid color on transparency. A multi-color
calendar won't tint correctly. If your chosen icon is mostly one color already,
it may work as-is; if it's colorful, either simplify it or use Option B.

In the **Asset Catalog**: create a new **Image Set** named `MenubarIcon`, drag
`MenubarIcon.png` into the **1x** slot and `MenubarIcon@2x.png` into **2x**.
Select the image set → in the **Attributes inspector**, set **Render As** to
**Template Image** (this is the asset-catalog equivalent of `isTemplate`).

### Option B — full color
If you'd rather keep the icon's colors, open `AppDelegate.swift` and change:

```swift
icon.isTemplate = true
```
to
```swift
icon.isTemplate = false
```
and set the image set's **Render As** to **Original Image**. It won't adapt to
the menu bar background, but it'll keep its colors.

> Either way, the app degrades gracefully: if no `MenubarIcon` asset is found,
> the menubar simply shows the date text with no icon, so nothing breaks while
> you're setting this up.

## Step 3 — attribution (required by the Flaticon license)

The Flaticon Free License requires a visible credit. This is already done — the
icon's author (Freepik) is filled in to both spots:

1. **In-app menu line** — `AppDelegate.swift` shows `Icon: Freepik / Flaticon`,
   which opens the source page when clicked.
2. **CREDITS.md** — the acknowledgements file carries the
   "Icon made by Freepik from www.flaticon.com" credit.

Together these satisfy the license's "visible spot / credits section"
requirement for a desktop app. No further action needed unless you swap the
icon for one by a different author, in which case update both spots.
