#!/usr/bin/env python3
"""
Hebrew Date Menubar — a macOS menubar item that displays today's Hebrew
calendar date alongside the Gregorian date, with genuine sunset awareness.

Data source: Hebcal.com REST APIs
  - Converter: https://www.hebcal.com/home/219/hebrew-date-converter-rest-api
  - Zmanim:    https://www.hebcal.com/home/1663/zmanim-halachic-times-api
Content from the Hebcal API is licensed CC-BY 4.0; attribution to Hebcal.com
is shown in the dropdown menu.

Requirements:
    pip3 install rumps

Run:
    python3 hebrew_date_menubar.py
"""

import datetime as _dt
import json
import threading
import time
import urllib.parse
import urllib.request
import urllib.error

import rumps

# ----------------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------------

CONVERTER_URL = "https://www.hebcal.com/converter"
ZMANIM_URL = "https://www.hebcal.com/zmanim"
APP_NAME = "Hebrew Date"
USER_AGENT = "HebrewDateMenubar/2.0 (+https://www.hebcal.com)"
REQUEST_TIMEOUT = 10  # seconds

# --- Location (used only to compute sunset) ---------------------------------
# Default: Munich, Germany. Set your own coordinates, or switch to a GeoNames
# ID or US ZIP by editing build_location_params() below.
LATITUDE = 48.1374
LONGITUDE = 11.5755

# --- Menubar display style ---------------------------------------------------
# "translit" -> "29 Iyyar 5771";  "hebrew" -> "כ״ט בְּאִיָיר תשע״א".
# Toggle live from the menu; this is just the startup default.
DEFAULT_MENUBAR_STYLE = "translit"

# --- Sunset mode --------------------------------------------------------------
# "auto"  -> advance to next Hebrew day automatically once past local sunset
# "on"    -> always treat as after sunset
# "off"   -> never (plain civil-day behavior)
DEFAULT_SUNSET_MODE = "auto"

MIN_REFRESH_INTERVAL = 60  # be polite to the free API


# ----------------------------------------------------------------------------
# Hebcal API client
# ----------------------------------------------------------------------------

class HebcalError(Exception):
    """Raised when a Hebcal API call fails or returns unusable data."""


def _get_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT) as resp:
            raw = resp.read().decode("utf-8")
    except urllib.error.HTTPError as e:
        raise HebcalError(f"HTTP {e.code} from Hebcal") from e
    except urllib.error.URLError as e:
        raise HebcalError(f"Network error: {e.reason}") from e
    except Exception as e:  # noqa: BLE001
        raise HebcalError(str(e)) from e
    try:
        return json.loads(raw)
    except json.JSONDecodeError as e:
        raise HebcalError("Could not parse Hebcal response") from e


def build_location_params():
    """Return the location query params for the Zmanim API.

    Edit this to use a GeoNames ID ({'geonameid': 2867714}) or US ZIP
    ({'zip': '90210'}) instead of latitude/longitude if you prefer.
    """
    return {"latitude": LATITUDE, "longitude": LONGITUDE}


def fetch_hebrew_date(greg_date, after_sunset=False):
    """Convert a Gregorian date to Hebrew via the Hebcal converter API."""
    params = {
        "cfg": "json",
        "g2h": "1",
        "strict": "1",
        "date": greg_date.isoformat(),
    }
    if after_sunset:
        params["gs"] = "on"
    data = _get_json(CONVERTER_URL + "?" + urllib.parse.urlencode(params))
    for key in ("hy", "hm", "hd", "hebrew"):
        if key not in data:
            raise HebcalError(f"Hebcal response missing '{key}'")
    return data


def fetch_sunset(greg_date):
    """Return today's sunset as a timezone-aware datetime, or None on failure."""
    params = {"cfg": "json", "date": greg_date.isoformat()}
    params.update(build_location_params())
    try:
        data = _get_json(ZMANIM_URL + "?" + urllib.parse.urlencode(params))
        sunset_iso = data.get("times", {}).get("sunset")
        if not sunset_iso:
            return None
        # Python 3.7+ parses the ISO-8601 offset (e.g. +02:00) directly.
        return _dt.datetime.fromisoformat(sunset_iso)
    except (HebcalError, ValueError):
        return None


# ----------------------------------------------------------------------------
# Formatting helpers
# ----------------------------------------------------------------------------

def format_translit(data):
    return f"{data['hd']} {data['hm']} {data['hy']}"


def format_hebrew(data):
    return data.get("hebrew", format_translit(data))


def format_gregorian(greg_date):
    try:
        return greg_date.strftime("%A, %B %-d, %Y")
    except ValueError:
        return greg_date.strftime("%A, %B %d, %Y")


# ----------------------------------------------------------------------------
# The menubar application
# ----------------------------------------------------------------------------

class HebrewDateApp(rumps.App):
    def __init__(self):
        super().__init__(APP_NAME, title="…", quit_button=None)

        self._style = DEFAULT_MENUBAR_STYLE
        self._sunset_mode = DEFAULT_SUNSET_MODE
        self._last_fetch_monotonic = 0.0
        self._last_data = None
        self._sunset_dt = None          # cached sunset for today (aware datetime)
        self._sunset_fetched_for = None  # date the cached sunset is valid for
        self._effective_after_sunset = False
        self._lock = threading.Lock()

        # Dropdown items
        self.item_hebrew = rumps.MenuItem("")
        self.item_gregorian = rumps.MenuItem("")
        self.item_events = rumps.MenuItem("")
        self.item_sunset_status = rumps.MenuItem("")

        # Display-style submenu
        self.style_translit = rumps.MenuItem(
            "Transliterated (29 Iyyar 5771)", callback=self._set_style_translit
        )
        self.style_hebrew = rumps.MenuItem(
            "Hebrew letters (כ״ט בְּאִיָיר…)", callback=self._set_style_hebrew
        )
        style_menu = rumps.MenuItem("Menubar style")
        style_menu.add(self.style_translit)
        style_menu.add(self.style_hebrew)

        # Sunset-mode submenu
        self.mode_auto = rumps.MenuItem("Auto (at local sunset)", callback=self._set_mode_auto)
        self.mode_on = rumps.MenuItem("Always after sunset", callback=self._set_mode_on)
        self.mode_off = rumps.MenuItem("Never (civil day)", callback=self._set_mode_off)
        sunset_menu = rumps.MenuItem("Sunset mode")
        sunset_menu.add(self.mode_auto)
        sunset_menu.add(self.mode_on)
        sunset_menu.add(self.mode_off)

        self.menu = [
            self.item_hebrew,
            self.item_gregorian,
            None,
            self.item_events,
            self.item_sunset_status,
            None,
            style_menu,
            sunset_menu,
            rumps.MenuItem("Refresh now", callback=self._manual_refresh),
            None,
            rumps.MenuItem("Dates by Hebcal.com", callback=self._open_hebcal),
            rumps.MenuItem("Quit", callback=rumps.quit_application),
        ]

        self._sync_checkmarks()
        self._refresh_async()

    # -- periodic refresh -----------------------------------------------------

    @rumps.timer(120)  # every 2 min: catches midnight + the sunset crossing
    def _scheduled_tick(self, _sender):
        self._refresh_async()

    # -- style actions --------------------------------------------------------

    def _set_style_translit(self, _s):
        self._style = "translit"; self._sync_checkmarks(); self._rerender()

    def _set_style_hebrew(self, _s):
        self._style = "hebrew"; self._sync_checkmarks(); self._rerender()

    # -- sunset-mode actions --------------------------------------------------

    def _set_mode_auto(self, _s):
        self._sunset_mode = "auto"; self._sync_checkmarks(); self._refresh_async(force=True)

    def _set_mode_on(self, _s):
        self._sunset_mode = "on"; self._sync_checkmarks(); self._refresh_async(force=True)

    def _set_mode_off(self, _s):
        self._sunset_mode = "off"; self._sync_checkmarks(); self._refresh_async(force=True)

    def _sync_checkmarks(self):
        self.style_translit.state = self._style == "translit"
        self.style_hebrew.state = self._style == "hebrew"
        self.mode_auto.state = self._sunset_mode == "auto"
        self.mode_on.state = self._sunset_mode == "on"
        self.mode_off.state = self._sunset_mode == "off"

    # -- misc actions ---------------------------------------------------------

    def _manual_refresh(self, _s):
        self._refresh_async(force=True)

    def _open_hebcal(self, _s):
        import webbrowser
        webbrowser.open("https://www.hebcal.com/converter")

    # -- sunset logic ---------------------------------------------------------

    def _resolve_after_sunset(self, today):
        """Decide whether the Hebrew date should be advanced right now."""
        if self._sunset_mode == "on":
            return True
        if self._sunset_mode == "off":
            return False

        # auto: need today's sunset. Fetch (and cache) if we don't have it.
        if self._sunset_fetched_for != today or self._sunset_dt is None:
            s = fetch_sunset(today)
            self._sunset_dt = s
            self._sunset_fetched_for = today

        if self._sunset_dt is None:
            # Couldn't determine sunset; fail safe to civil day (not advanced).
            return False

        now = _dt.datetime.now(self._sunset_dt.tzinfo)
        return now >= self._sunset_dt

    # -- refresh plumbing -----------------------------------------------------

    def _refresh_async(self, force=False):
        threading.Thread(target=self._refresh, kwargs={"force": force}, daemon=True).start()

    def _refresh(self, force=False):
        with self._lock:
            now = time.monotonic()
            if not force and (now - self._last_fetch_monotonic) < MIN_REFRESH_INTERVAL:
                if self._last_data is not None:
                    self._render(self._last_data)
                return
            self._last_fetch_monotonic = now

        today = _dt.date.today()
        after_sunset = self._resolve_after_sunset(today)
        self._effective_after_sunset = after_sunset

        try:
            data = fetch_hebrew_date(today, after_sunset=after_sunset)
        except HebcalError as e:
            self._render_error(str(e))
            return

        with self._lock:
            self._last_data = data
        self._render(data)

    # -- rendering ------------------------------------------------------------

    def _title_for(self, data):
        return format_hebrew(data) if self._style == "hebrew" else format_translit(data)

    def _rerender(self):
        if self._last_data is not None:
            self._render(self._last_data)

    def _render(self, data):
        self.title = self._title_for(data)
        self.item_hebrew.title = format_hebrew(data)
        self.item_gregorian.title = format_gregorian(_dt.date.today())

        events = data.get("events") or []
        self.item_events.title = "  •  ".join(events) if events else "No events today"

        # Sunset status line
        if self._sunset_mode == "auto":
            if self._sunset_dt is not None:
                hhmm = self._sunset_dt.strftime("%-H:%M") if _supports_dash() \
                    else self._sunset_dt.strftime("%H:%M")
                state = "after sunset → next day" if self._effective_after_sunset \
                    else "before sunset"
                self.item_sunset_status.title = f"Sunset {hhmm} ({state})"
            else:
                self.item_sunset_status.title = "Sunset time unavailable (using civil day)"
        elif self._sunset_mode == "on":
            self.item_sunset_status.title = "Mode: always after sunset"
        else:
            self.item_sunset_status.title = "Mode: civil day"

    def _render_error(self, msg):
        if self._last_data is not None:
            self.title = self._title_for(self._last_data) + " ⚠"
            self.item_events.title = f"Offline — last update shown ({msg})"
        else:
            self.title = "Hebrew Date ⚠"
            self.item_hebrew.title = "Couldn't reach Hebcal"
            self.item_gregorian.title = msg
            self.item_events.title = "Will retry automatically"


def _supports_dash():
    """True if strftime supports the %-H no-pad extension (glibc/BSD/macOS)."""
    try:
        _dt.datetime(2000, 1, 1, 5, 0).strftime("%-H")
        return True
    except ValueError:
        return False


if __name__ == "__main__":
    HebrewDateApp().run()
