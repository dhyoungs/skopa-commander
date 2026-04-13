# CLAUDE.md — SKOPA Commander

Context for Claude AI working on this repository.

---

## What this is

A **single-file kiosk web application** (`index.html`) for a naval tactical command station. It controls a Raspberry Pi silo weapons system via HTTP API, shows situational awareness on a map, and provides maintenance utilities. Served by a tiny Python HTTP server (`server.py`) on port 5000.

---

## Key files

| File | Role |
|---|---|
| `index.html` | The entire application — all HTML, CSS, JS in one file. No build step. |
| `server.py` | Python `http.server` that serves `index.html` and exposes `/sysinfo` (IP + HW uptime). |
| `setup.sh` | Automated installer for Ubuntu 22.04/24.04: installs Chrome, creates systemd user service, GNOME autostart. |
| `README.md` | Human-readable setup and usage guide. |
| `icon.svg` | Application icon. |

---

## Architecture

```
Browser (kiosk)
    └── index.html
          ├── fetches /sysinfo  →  server.py (localhost:5000)
          └── fetches Pi API    →  Raspberry Pi (LAN, port 5000)
                                     POST /api/open
                                     POST /api/close
                                     GET  /api/config/relay_state
                                     GET  /api/status
                                     GET  /api/telemetry
```

Chrome runs with `--disable-web-security` so cross-origin Pi API calls work from `file://`. When served via `http://localhost:5000` no flag is needed.

---

## Pi SiloController API (the target hardware)

Pi runs [dhyoungs/SiloController](https://github.com/dhyoungs/SiloController) Flask app on port 5000.

| Endpoint | Method | Returns |
|---|---|---|
| `/api/open` | POST | `{"ok":true}` |
| `/api/close` | POST | `{"ok":true}` |
| `/api/config/relay_state` | GET | `{"relay_open":bool,"state":"open\|opening\|closed\|closing","travel_time":float}` |
| `/api/status` | GET | `{"recording":bool,"state":"open\|closed","uptime_s":int}` |
| `/api/telemetry` | GET | GPS/IMU data: lat, lon, fix, sats, hdop, speed, cog, pitch, roll |

**Important**: endpoints are `/api/open` and `/api/close` — NOT `/api/silo/open`. The Pi always listens on port 5000.

---

## index.html internals

### Tabs
- **Tab 0 — SKOPA COMMANDER**: main silo control panel + situational awareness map
- **Tab 1 — PATRICK BLACKETT TELEM**: Pi iframe + live telemetry feed
- **Tab 2 — MAINTENANCE**: manual silo open/close test buttons, weapons registry, silo 2 reload

### Silo state machine (Silo 2, the active silo)

States: `PENDING` → `AUTHORISED` → `LAUNCHING` → `OPEN`/`EMPTY` → `CLOSING` → `CLOSED`

```
PENDING      — countdown running; "AUTHORISE LAUNCH" button
AUTHORISED   — PIN accepted; "LAUNCH IMMEDIATE" + "ABORT" buttons
LAUNCHING    — POST /api/open sent; 60s abort window; 2-min timer
EMPTY        — 2 min elapsed; "Close Silo" button shown
OPEN         — abort was pressed; "Close Silo" button
CLOSING      — POST /api/close sent; 30s timer
CLOSED       — final; no further action
```

Key globals:
```javascript
let siloState = 'PENDING';
let launchingStart = 0;
let launchEmptyTimer = null;
let LAUNCH_DEADLINE = Date.now() + (16 * 60 + 32) * 1000;  // let — must be reassignable
const ABORT_WINDOW_MS    = 60 * 1000;
const LAUNCH_DURATION_MS = 120 * 1000;
```

### Pi connection / API helpers

```javascript
const STORAGE_KEY = 'skopa_pi_ip';  // localStorage — stores bare IP only (no protocol, no port)
function normPiIp(raw)       // strips protocol + port, returns bare IP
function getPiBaseAddr()     // returns 'http://IP:5000' or null
async function piApiPost(path, data={})  // POST with GET fallback on 405; logs to siloLog()
async function piApiGet(path)            // GET with JSON response
```

### Debug log

`siloLog(msg, cls)` writes to **all** `.api-log-area` elements (class, not ID) so both Commander tab and Maintenance tab show the same log. Classes: `prep`, `sending`, `ok`, `err`.

### Relay lid polling

```javascript
let piSiloLid = { state:'unknown', travel_time:1.0, since:0, relay_open:false };
let relayPollInterval = null;
function startRelayPoll(baseAddr)   // polls /api/config/relay_state every 2000ms
function updateSilo2LidDisplay()    // updates #silo2-lid-status in the silo grid
```

`piSiloLid.since` is set to `Date.now()` whenever `state` changes, enabling elapsed/remaining progress display.

### System status bar (top-right)

Reads `/sysinfo` from `localhost:5000` every 5 seconds. Element IDs:
- `#hm-ip` — LAN IP
- `#hm-swup` — software (app) uptime HH:MM:SS
- `#hm-hwup` — hardware uptime HH:MM:SS (extrapolated between fetches)
- `#outer-clock` — UTC HH:MM:SS.mmm

### Countdown

`LAUNCH_DEADLINE` is a `let` so `reloadSilo2()` can reset it. Format: `MM:SS.mmm`. Updated every 100ms in the main tick interval (same interval as clock and lid progress).

### Silo grid

8 silos defined in `const SILOS = [...]`. Only Silo 2 (`SILOS[1]`) is the "active" silo. The silo grid is rebuilt by `renderSilos()` — after calling it, always call `updateSilo2LidDisplay()` to restore the lid status element (it gets wiped on rebuild).

### Maintenance tab

- Manual test buttons: 8 rows × 3 buttons (Open / Close / Status) — calls `piApiPost('/api/open')` etc.
- Weapons registry (CRUD): stored in `let weaponTypes = [...]`.
- Silo 2 reload/reset: calls `reloadSilo2()` to reset state machine + refill SILOS[1].
- API log: `#maint-api-log` with class `api-log-area` — receives same `siloLog()` output as commander tab.

### Map (Situational Awareness)

Mercator projection, English Channel centred. Vessel track from GPS telemetry. Supports mouse/touch zoom + pan.

---

## How to extend

- **Add a new Pi API call**: use `piApiPost(path)` or `piApiGet(path)` — they handle base address, CORS, logging automatically.
- **Add a new tab**: add a `<div class="tab-btn">` in the tabbar and a corresponding `<div class="tab-pane">` in the content area.
- **Add a new silo**: push to `const SILOS`, update `renderSilos()`.
- **Change launch parameters**: edit `ABORT_WINDOW_MS`, `LAUNCH_DURATION_MS`, `LAUNCH_DEADLINE` initial value.
- **Change auth PIN**: edit `const AUTH_CODE` near the top of the `<script>` block.

---

## Running locally

```bash
python3 server.py          # serves http://0.0.0.0:5000
# Open http://localhost:5000 in browser
```

Or open `index.html` directly in Chrome with `--disable-web-security --user-data-dir=/tmp/test`.

---

## Common pitfalls

- `LAUNCH_DEADLINE` must be `let`, not `const` — `reloadSilo2()` reassigns it.
- Call `updateSilo2LidDisplay()` after every `renderSilos()` call or the lid row disappears.
- `siloLog()` must target `.api-log-area` (class selector), not `#silo-api-log` (ID), so both tabs receive log output.
- Pi API endpoints: `/api/open` and `/api/close` — not `/api/silo/open`.
- Storing the Pi IP: use `normPiIp()` before saving to `localStorage` — strips any accidentally-pasted protocol or port.
