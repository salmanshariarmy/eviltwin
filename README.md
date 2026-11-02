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
