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
- **Date links** (Swift version only): the Hebrew date opens the day on
  Chabad.org, and the Gregorian date opens an article from the same day of the
  year in the News Articles Archive. See [Date links](#date-links).
- **Zmanim** (Swift version only): the next zman, candle lighting and havdalah in
  the menu, and all the day's zmanim in a submenu. See [Zmanim](#zmanim).
- **Learning and davening** (Swift version only): Daf Yomi, Mishnah Yomi,
  Yerushalmi Yomi, Nach Yomi and the Torah reading, and the day's changes to
  the davening for your nusach in a submenu. See [Learning and davening](#learning-and-davening).
- Degrades gracefully offline: keeps the last good value with a ⚠, and if
  sunset can't be fetched, Auto mode safely falls back to the civil day.

## Install the Swift version

To build and install the Swift version, use `install.sh` in the root folder of the repository:

```bash
bash install.sh          # show the commands
bash install.sh | bash   # build and install
```

For the script, it is necessary to have Bash 4.2 or higher and the Xcode command-line tools. For more information, refer to Option B in `XCODE_SETUP.md`.

## Which should I run?

| | Python | Swift |
| --- | --- | --- |
| Setup | `pip3 install rumps`, run | `bash install.sh \| bash`, or an Xcode project (guide included) |
| Startup speed | instant | compiled, slightly faster runtime |
| Distribution | needs Python + rumps | self-contained `.app`, signable |
| Best for | quick use, hacking | learning native macOS, sharing |
| Lock screen date | no | yes |
| Learning and davening | no | yes |

## Sunset awareness — how it actually works

The Hebcal converter's `gs=on` flag only means "treat as after sunset"; it
doesn't know *when* sunset is. So in Auto mode the app first calls the **Zmanim
API** for today's `sunset` (an ISO-8601 time with timezone offset for your
location), compares it to the current time, and only then asks the converter
for the advanced date if sunset has passed. The Swift version uses the Mac's
current location (see [Location](#location)); the Python version uses Munich.

## Location

The Swift version calculates the sunset for the current location of the Mac. It uses Location Services with a precision of approximately 1 km. It gets the time zone and the name of the location from the Apple geocoding service.

When the current location is not available, the app uses a fallback location. The default fallback location is Munich. The app uses the fallback location in these conditions:

- You did not give permission for Location Services, or you set **Use current location** to off.
- The Mac cannot find its location, and the app has no location from before.

The sunset line in the menu shows the location, for example "Sunset 18:59 in Munich (before sunset)". The **Location** submenu shows the location that the app uses, and the cause.

To set a different fallback location:

1. In the menu, select **Location** > **Set fallback location…**.
2. Type a city, for example `Jerusalem`. You can also type coordinates as `lat, lon`, as `lat, lon, Area/City` with a time zone, or as `lat, lon, Area/City, metres` with a time zone and an elevation.
3. Click **Set**.

To use Munich again, select **Location** > **Reset fallback to Munich**.

When the app starts for the first time, macOS shows a permission dialog for your location. If you do not give permission, open **System Settings** > **Privacy & Security** > **Location Services** and set **Hebcal4Menubar** to on. The **Location** submenu then shows a menu item that opens these settings.

macOS keeps the permission for one signature of the app. `install.sh` gives the app an ad-hoc signature, which changes with each build. Thus, macOS can show the permission dialog again after each installation. To keep the permission, sign the app with a certificate:

```bash
CODESIGN_IDENTITY='Apple Development: …' bash install.sh | bash
```

### Elevation

Hebcal can calculate the sunset for the elevation of a location. At a high elevation, the sunset occurs after the sunset at sea level. For example, in Munich (524 m) the difference is 5 minutes. This is the same as the **Use elevation** check box in the calendar of hebcal.com.

To use the elevation, select **Location** > **Use elevation for sunset**. The default is off, the same as on hebcal.com.

The app gets the elevation from these sources, in this sequence:

1. Location Services, when the Mac gives a correct altitude. Most Macs do not have GPS. Thus, this source is not frequent.
2. The Open-Meteo elevation service. The app sends the coordinates to Open-Meteo only when **Use elevation for sunset** is on.
3. Your entry in **Set fallback location…**, as `lat, lon, Area/City, metres`. For example: `48.14, 11.58, Europe/Berlin, 524`.

Hebcal does not use an elevation of 0 m or less. Thus, for a location below sea level, the app calculates the sunset at sea level.

The Python version uses the coordinates in its code (Munich) and does not use Location Services.

## Date links

In the Swift version, the two date lines at the top of the menu are links:

- Click the Hebrew date to open the day view of the Chabad.org calendar.
- Click the Gregorian date to open the News Articles Archive (kvetch-of-the-day.github.io) at an article from the same day of the year. The year of the article is not important. If no article has today's day and month, the link uses the article with the nearest day. Put the pointer on the line to see the date and the title of the article.

You cannot put a date in the address of the archive page. Thus, the app downloads the archive page one time each day and finds the article. The link uses a text fragment (`#:~:text=`) to go to the date of the article on the page. When more than one article has the same day, the link goes to the first of these articles on the page. If the app cannot download the archive page, the link opens the top of the page.

## Zmanim

The Swift version shows the zmanim for the location of the sunset line (refer to [Location](#location)). The times are in the time zone of that location. If this time zone is different from the time zone of your Mac, the menu shows the time zone after the time.

The main menu shows these lines below the sunset line:

- **Next**: the next zman, and the time until it, for example "Next: Latest Shema (GRA) 10:07 · in 27 min".
- **Candle lighting**: the next candle lighting times for Shabbat and Yom Tov. When Yom Tov is before or after Shabbat, the line shows each candle lighting time.
- **Havdalah**: the time of the next havdalah.

The **Zmanim** submenu shows all the zmanim of the day. The symbol ▸ and bold text show the next zman. The first zman of the day is chatzot halayla, the midnight at the start of the day. After tzeit hakochavim, the next zman is the chatzot halayla of the night. Thus, the submenu then shows the zmanim of the next day.

| Zman | Opinion |
| --- | --- |
| Chatzot halayla | The midnight at the start of the day |
| Alot hashachar | 16.1° |
| Misheyakir | 11.5° and 10.2° |
| Sunrise | — |
| Latest Shema, latest Tefilla | MGA (72 minutes) and GRA |
| Chatzot | — |
| Mincha gedola, mincha ketana, plag hamincha | GRA |
| Sunset | — |
| Tzeit hakochavim | 8.5° |

Candle lighting is 18 minutes before sunset. Havdalah is at tzeit hakochavim (8.5°). When **Use elevation for sunset** is on, the sunrise, the sunset and the candle lighting include the elevation.

The app gets the zmanim from the Hebcal Zmanim API one time for each day and location. It gets the candle lighting and havdalah times from the Hebcal calendar API, with the Yom Tov days included.

## Learning and davening

The Swift version shows the **Davening** submenu below the **Zmanim** submenu, and the **Learning** section below the **Davening** submenu. The Python version does not have these items.

### Learning

The **Learning** section shows the daily learning schedules and the Torah reading for the Hebrew day on the menu:

- Daf Yomi, Mishnah Yomi, Yerushalmi Yomi and Nach Yomi. Click a line to open the text on Sefaria.
- The Torah reading, when there is one: Monday and Thursday, Rosh Chodesh, fasts, festivals and Shabbat. Click the line to open the first reading on Sefaria.

The app gets these data from the Hebcal API one time for each Hebrew day. When the Mac is offline, the menu keeps the last data. To show or hide a schedule, use the **Learning schedules** submenu. The **Menubar style** submenu also sets the language of the learning lines.

### Davening

The **Davening** submenu shows the changes to the prayers for the Hebrew day on the menu. Examples are Ya'aleh v'yavo, Hallel, Tachanun, Sefirat haOmer and Kiddush Levanah. The app calculates these changes on your Mac. Thus, this submenu operates without a network connection.

Use the **Nusach** submenu to select Ashkenaz, Sefard (chassidic), Chabad or Edot HaMizrach. In the same submenu, select **Eretz Yisrael (Israel customs)** for the customs of Israel. The default is Ashkenaz in the diaspora.

`DAVENING_RULES.md` gives all the rules and a test table. `tools/verify.sh` compares the calendar data of the app with Hebcal.

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
