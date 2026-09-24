# Hebrew Date Menubar

A macOS menubar item showing today's **Hebrew calendar date** next to the
**Gregorian date**, with a live toggle between display styles and genuine
**sunset awareness**. Two implementations are included:

- **`hebrew_date_menubar.py`** — Python (rumps). Fastest to run and tinker with.
- **`Hebcal4Menubar/`** — native Swift/AppKit app for Xcode. See
  `XCODE_SETUP.md`.

Both behave identically and pull data from the same source:
[Hebcal.com](https://www.hebcal.com) — the converter API for the date and the
zmanim API for sunset.

## Features

- Menubar shows the date; click for Hebrew-letters form, full Gregorian date,
  and today's events (Torah portion, Omer count, holidays, Rosh Chodesh).
- **Menubar style** toggle: transliterated (`29 Iyyar 5771`) or Hebrew letters
  (`כ״ט בְּאִיָיר תשע״א`).
- **Sunset mode**:
  - **Auto** — fetches your local sunset and advances to the next Hebrew day
    automatically once the clock passes it (the traditional day boundary).
  - **Always after sunset** / **Never** — manual overrides.
- Refreshes every ~2 min so midnight and sunset rollovers happen on their own.
- **Lock screen date** (Swift version only): the Hebrew date shows above the
  macOS date on the lock screen. See [Lock screen date](#lock-screen-date).
- Degrades gracefully offline: keeps the last good value with a ⚠, and if
  sunset can't be fetched, Auto mode safely falls back to the civil day.

## Which should I run?

| | Python | Swift |
| --- | --- | --- |
| Setup | `pip3 install rumps`, run | Create Xcode project (guide included) |
| Startup speed | instant | compiled, slightly faster runtime |
| Distribution | needs Python + rumps | self-contained `.app`, signable |
| Best for | quick use, hacking | learning native macOS, sharing |
| Lock screen date | no | yes |

## Sunset awareness — how it actually works

The Hebcal converter's `gs=on` flag only means "treat as after sunset"; it
doesn't know *when* sunset is. So in Auto mode the app first calls the **Zmanim
API** for today's `sunset` (an ISO-8601 time with timezone offset for your
location), compares it to the current time, and only then asks the converter
for the advanced date if sunset has passed. Location defaults to Munich and is
a one-line change in both versions.

## Lock screen date

The Swift version also shows the Hebrew date on the macOS lock screen. The app shows the Hebrew date immediately above the macOS date, which is above the clock.

macOS does not have lock screen widgets or an alternative calendar for the lock screen. Thus, the app uses the private SkyLight framework. The app makes a window-server space at the level that Notification Center uses on the lock screen. Then the app moves a small window into that space. The app shows the window only when the screen is locked. The window ignores mouse clicks.

The glass style copies the style of the macOS date. A blur of the wallpaper shows through the letters. A white fill adds light to the blur with a "plus lighter" blend mode. Thus, the letters get the color of the wallpaper behind them.

### Lock screen settings

Use the **Lock screen** submenu:

- **Show on lock screen**: set the lock screen date to on or off.
- **Position: above date** (default) or **Position: near bottom**.
- **Style: glass** (default) or **Style: plain white** (white text with a shadow).

The lock screen date uses the same text style as the menubar (transliterated or Hebrew letters).

To adjust the position or the opacity, refer to [Advanced settings](#advanced-settings).

### Advanced settings

Two `defaults` keys adjust the lock screen date. The menu does not show these keys. To apply a new value, stop the app (menu item **Quit**) and start it again.

The commands use the domain `com.example.Hebcal4Menubar`. This domain is the `CFBundleIdentifier` in `Info.plist`. If you change the identifier, use the new identifier in the commands.

To see the current values, use this command:

```bash
defaults read com.example.Hebcal4Menubar
```

#### Adjust the position (`lockScreenNudge`)

Use `lockScreenNudge` when the Hebrew date is too near the macOS date, or too far from the macOS date. This can occur on a display that is different from 3440 × 1440. For example, a MacBook display with a notch can move the macOS date.

The value is in points. A positive value moves the Hebrew date up. A negative value moves the Hebrew date down. The default value is 0.

1. Lock the screen (Control-Command-Q).
2. Look at the distance between the Hebrew date and the macOS date.
3. Unlock the screen.
4. Set a small value, for example 4 or -4:

    ```bash
    defaults write com.example.Hebcal4Menubar lockScreenNudge -float 4
    ```

5. Stop the app (menu item **Quit**) and start it again.
6. If the distance is not correct, do steps 1 to 5 again.

To remove the adjustment, use this command:

```bash
defaults delete com.example.Hebcal4Menubar lockScreenNudge
```

#### Adjust the glass opacity (`lockScreenGlassAlpha`)

Use `lockScreenGlassAlpha` when the Hebrew date is brighter or darker than the macOS date. This can occur with a different wallpaper or after a macOS update. The value has an effect only on the glass style.

The value is the opacity of the white fill, from 0 to 1. The default value is 0.56. A higher value makes the Hebrew date brighter. A lower value lets more color of the wallpaper show through the letters. The value 0 sets the default value again.

1. Set a value. Change the value in steps of approximately 0.05:

    ```bash
    defaults write com.example.Hebcal4Menubar lockScreenGlassAlpha -float 0.6
    ```

2. Stop the app (menu item **Quit**) and start it again.
3. Lock the screen (Control-Command-Q).
4. Compare the Hebrew date with the macOS date.
5. If the brightness is not correct, unlock the screen and do steps 1 to 4 again.

To remove the adjustment, use this command:

```bash
defaults delete com.example.Hebcal4Menubar lockScreenGlassAlpha
```

### Limits

- The default position comes from measurements on macOS 27 with a 3440 × 1440 display. On other displays, adjust the position with `lockScreenNudge` (refer to [Advanced settings](#advanced-settings)).
- The app shows the lock screen date only on the primary display (the display with the menubar).
- A macOS update can change private APIs. If the SkyLight functions are not available, the app stops the lock screen date. The menu then shows "Lock screen (unavailable on this macOS)". The menubar date continues to operate.
- Apple does not document the "plusL" blend mode. If macOS ignores the blend mode, the fill becomes a usual translucent overlay.
- The Python version does not have the lock screen date.

## Attribution & license

Hebrew date and zmanim content is generated by the Hebcal.com web APIs and is
licensed under [CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/).
Credit to Hebcal.com appears in the app menu, satisfying that requirement.

The lock screen method comes from
[SkyLightWindow](https://github.com/Lakr233/SkyLightWindow) by Lakr233
(MIT license).
