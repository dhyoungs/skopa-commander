# SKOPA Commander

**Naval Tactical Command System** — full-screen kiosk web application for monitoring and controlling the SKOPA silo weapons programme from a shore or vessel tactical station.

---

## What it does

- **Silo Control** — monitors all 8 silo bays (PB-Aft-1 through PB-Aft-8), shows loaded weapon, capability, status, and live silo lid state (Open/Opening/Closed/Closing) from the Pi API
- **Launch Authorisation** — scheduled launch countdown with PIN-protected authorisation flow; abort at any stage
- **Launch Immediate** — separate PIN-gated immediate-launch flow; sends silo-open command to Pi; 1-minute abort window; 2-minute launch phase; Close Silo controls
- **Situational Awareness** — English Channel Mercator map with vessel track, zoom/pan, live GPS telemetry (lat, lon, fix, sats, HDOP, speed, COG, pitch, roll)
- **Patrick Blackett Telem** — embedded iframe of the Pi's own web UI plus live telemetry feed
- **Maintenance** — manual silo open/close API test controls for all 8 bays; Skopa weapons type registry (create/edit/delete); Silo 2 reload/reset
- **System status bar** — IP address, SW uptime, HW uptime, UTC clock with milliseconds (all live)

---

## Hardware requirements

| Component | Detail |
|---|---|
| Tactical station PC | x86-64, Ubuntu 22.04+ or 24.04, GNOME desktop |
| Display | Full HD (1920×1080) or larger, landscape |
| Network | Same LAN as the Pi silo controller |
| Pi silo controller | Raspberry Pi running [SiloController](https://github.com/dhyoungs/SiloController) on port 5000 |

---

## Quick install (fresh machine)

```bash
# Install git if not present
sudo apt-get install -y git

# Clone and run setup
git clone https://github.com/dhyoungs/skopa-commander.git
cd skopa-commander
bash setup.sh
```

`setup.sh` will:
1. Install `git`, `python3`, `wget`, `curl` via apt
2. Install Google Chrome (stable) if absent
3. Clone / update this repository to `~/skopa-commander`
4. Create and enable a **systemd user service** that serves the UI on port 5000
5. Enable **loginctl linger** so the service survives logout
6. Create a GNOME **autostart entry** to launch Chrome in kiosk mode on login
7. Add a **Desktop shortcut**

---

## Manual setup (step by step)

### 1 — Clone the repo
```bash
git clone https://github.com/dhyoungs/skopa-commander.git ~/skopa-commander
```

### 2 — Run the web server (LAN access on port 5000)
```bash
python3 ~/skopa-commander/server.py
```
Or as a persistent service:
```bash
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/skopa-commander.service <<'EOF'
[Unit]
Description=SKOPA Commander Web Server
After=network.target

[Service]
Type=simple
WorkingDirectory=/home/YOUR_USER/skopa-commander
ExecStart=/usr/bin/python3 /home/YOUR_USER/skopa-commander/server.py
Restart=on-failure

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now skopa-commander.service
loginctl enable-linger $USER
```

### 3 — Kiosk launch (full-screen, touch-friendly)
```bash
google-chrome \
  --kiosk \
  --noerrdialogs \
  --disable-infobars \
  --no-first-run \
  --disable-session-crashed-bubble \
  --disable-restore-session-state \
  --disable-translate \
  --hide-scrollbars \
  --disable-pinch \
  --overscroll-history-navigation=0 \
  --disable-web-security \
  --user-data-dir=/tmp/skopa-kiosk \
  "file:///home/$USER/skopa-commander/index.html"
```

Or via LAN (no `--disable-web-security` needed when served over HTTP):
```bash
google-chrome --kiosk "http://localhost:5000"
```

### 4 — GNOME autostart on login
```bash
cp ~/skopa-commander/setup.sh /tmp && bash /tmp/setup.sh
# The autostart .desktop file is created by setup.sh
```

---

## Connecting to the Pi silo controller

1. Open the **Patrick Blackett Telem** tab
2. Enter the Pi's IP address (e.g. `10.100.151.193`) — port 5000 is assumed
3. Click **Connect** — the Pi's web UI loads in the iframe and telemetry/relay polling begins automatically

The Pi must be running [SiloController](https://github.com/dhyoungs/SiloController). The relevant Pi API endpoints used:

| Endpoint | Method | Purpose |
|---|---|---|
| `/api/open` | POST | Open silo lid |
| `/api/close` | POST | Close silo lid |
| `/api/config/relay_state` | GET | Live lid state + travel_time |
| `/api/status` | GET | Silo state + uptime |
| `/api/telemetry` | GET | GPS / IMU telemetry |

---

## Layout

```
┌─[SKOPA COMMANDER]──────────────────────────────────────────────────────┐
│ ◈ SKOPA COMMANDER  │ ◈ PATRICK BLACKETT TELEM  │ ◈ MAINTENANCE      UTC│
├──────────┬─────────────────────────────────────┬────────────────────────┤
│          │                                     │  SHIP SYSTEMS          │
│  SITUA-  │  ┌──────┬──────┬──────┬──────┐      ├────────────────────────┤
│  TIONAL  │  │Silo 1│Silo 2│Silo 3│Silo 4│      │  MISSION STATUS        │
│  AWARE-  │  ├──────┼──────┼──────┼──────┤      │                        │
│  NESS    │  │Silo 5│Silo 6│Silo 7│Silo 8│      │                        │
│  (map)   │  └──────┴──────┴──────┴──────┘      │                        │
│          │  SILO CONTROL                        │                        │
│  [telem] │  [API comms log]                     │                        │
└──────────┴─────────────────────────────────────┴────────────────────────┘
```

---

## Files

| File | Purpose |
|---|---|
| `index.html` | Entire application — single-file, no build step |
| `server.py` | Tiny Python HTTP server; serves `index.html` + `/sysinfo` endpoint |
| `setup.sh` | Automated fresh-machine setup script |
| `icon.svg` | Application icon |

---

## Auth code

Default launch authorisation PIN: **1234**
(defined as `AUTH_CODE` in `index.html`)

---

## Updating

```bash
cd ~/skopa-commander
git pull
systemctl --user restart skopa-commander.service
# Reload the kiosk tab (F5) or relaunch Chrome
```
