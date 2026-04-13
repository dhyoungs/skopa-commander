#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# SKOPA Commander — Fresh-machine Setup Script
# Tested on Ubuntu 22.04 LTS / 24.04 LTS (x86-64)
# Run as the target user (not root). sudo password required for apt steps.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

REPO_URL="https://github.com/dhyoungs/skopa-commander.git"
INSTALL_DIR="$HOME/skopa-commander"
SERVICE_NAME="skopa-commander"

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║         SKOPA Commander — Automated Setup            ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# ── 1. System packages ────────────────────────────────────────────────────────
echo "[1/6] Installing system packages..."
sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends \
    git \
    python3 \
    python3-pip \
    wget \
    curl \
    ca-certificates \
    xdg-utils

# ── 2. Google Chrome ──────────────────────────────────────────────────────────
echo "[2/6] Checking for Google Chrome..."
if ! command -v google-chrome &>/dev/null && ! command -v google-chrome-stable &>/dev/null; then
    echo "  Installing Google Chrome..."
    wget -q -O /tmp/chrome.deb \
        "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
    sudo apt-get install -y /tmp/chrome.deb
    rm /tmp/chrome.deb
else
    echo "  Google Chrome already installed."
fi

# ── 3. Clone or update repo ───────────────────────────────────────────────────
echo "[3/6] Cloning / updating repository..."
if [ -d "$INSTALL_DIR/.git" ]; then
    echo "  Updating existing clone in $INSTALL_DIR"
    git -C "$INSTALL_DIR" pull --ff-only
else
    git clone "$REPO_URL" "$INSTALL_DIR"
fi
chmod +x "$INSTALL_DIR/setup.sh"

# ── 4. Systemd user service (web server on port 5000) ─────────────────────────
echo "[4/6] Setting up systemd user service..."
SERVICE_DIR="$HOME/.config/systemd/user"
mkdir -p "$SERVICE_DIR"

cat > "$SERVICE_DIR/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=SKOPA Commander Web Server
After=network.target

[Service]
Type=simple
WorkingDirectory=${INSTALL_DIR}
ExecStart=/usr/bin/python3 ${INSTALL_DIR}/server.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable  "${SERVICE_NAME}.service"
systemctl --user restart "${SERVICE_NAME}.service"

# Enable linger so the service survives logout / runs at boot
loginctl enable-linger "$(whoami)"

echo "  Service status:"
systemctl --user status "${SERVICE_NAME}.service" --no-pager -l | head -8

# ── 5. Desktop autostart (kiosk mode on login) ────────────────────────────────
echo "[5/6] Configuring GNOME autostart..."
AUTOSTART_DIR="$HOME/.config/autostart"
mkdir -p "$AUTOSTART_DIR"

cat > "$AUTOSTART_DIR/${SERVICE_NAME}.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=SKOPA Commander
Comment=Naval Tactical Command System — Kiosk Mode
Exec=google-chrome --kiosk --noerrdialogs --disable-infobars --no-first-run \
  --disable-session-crashed-bubble --disable-restore-session-state \
  --disable-translate --hide-scrollbars --disable-pinch \
  --overscroll-history-navigation=0 --disable-web-security \
  --user-data-dir=/tmp/skopa-kiosk \
  file://${INSTALL_DIR}/index.html
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=5
EOF

# Desktop launcher shortcut
DESKTOP_DIR="$HOME/Desktop"
mkdir -p "$DESKTOP_DIR"
cp "$AUTOSTART_DIR/${SERVICE_NAME}.desktop" "$DESKTOP_DIR/SKOPA-Commander.desktop"
# Add Icon line if not present
if ! grep -q "^Icon=" "$DESKTOP_DIR/SKOPA-Commander.desktop"; then
    echo "Icon=${INSTALL_DIR}/icon.svg" >> "$DESKTOP_DIR/SKOPA-Commander.desktop"
fi
chmod +x "$DESKTOP_DIR/SKOPA-Commander.desktop" 2>/dev/null || true
gio set "$DESKTOP_DIR/SKOPA-Commander.desktop" metadata::trusted true 2>/dev/null || true

# ── 6. Done ───────────────────────────────────────────────────────────────────
echo ""
echo "[6/6] Setup complete."
echo ""
LAN_IP=$(python3 -c "import socket; s=socket.socket(); s.connect(('8.8.8.8',80)); print(s.getsockname()[0]); s.close()" 2>/dev/null || hostname -I | awk '{print $1}')
echo "  ┌──────────────────────────────────────────────────────┐"
echo "  │  SKOPA Commander is ready.                           │"
echo "  │                                                      │"
echo "  │  Kiosk (local):  file://${INSTALL_DIR}/index.html"
echo "  │  LAN web UI:     http://${LAN_IP}:5000              │"
echo "  │                                                      │"
echo "  │  The kiosk will auto-launch on next login.           │"
echo "  │  To launch now:  double-click SKOPA-Commander on     │"
echo "  │  the Desktop, or run:                                │"
echo "  │    google-chrome --kiosk ... file://...index.html    │"
echo "  └──────────────────────────────────────────────────────┘"
echo ""
echo "  To connect to the Pi silo controller:"
echo "    Open the 'Patrick Blackett Telem' tab and enter the Pi's IP."
echo "    Port 5000 is assumed automatically."
echo ""
