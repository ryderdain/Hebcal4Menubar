# Python version — quick reference

Run:

```bash
pip3 install rumps
python3 hebrew_date_menubar.py
```

Configuration lives in the block near the top of `hebrew_date_menubar.py`:

- `LATITUDE` / `LONGITUDE` — location for sunset (default: Munich).
- `DEFAULT_MENUBAR_STYLE` — `"translit"` or `"hebrew"` (also toggleable live).
- `DEFAULT_SUNSET_MODE` — `"auto"`, `"on"`, or `"off"` (also toggleable live).

Everything else mirrors the Swift app: the same menu layout, the same sunset
logic via the Zmanim API, and the same graceful-offline behavior.

Run at login: wrap it in an Automator "Run Shell Script" application
(`/usr/bin/python3 /full/path/to/hebrew_date_menubar.py`) and add that app to
**System Settings → General → Login Items**.
