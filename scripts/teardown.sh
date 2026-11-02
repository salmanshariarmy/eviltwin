#!/usr/bin/env bash
# teardown.sh — belt-and-suspenders cleanup, run on either laptop.
source "$(dirname "$0")/common.sh"
need_root
set +e
pkill -f hostapd
pkill -f "dnsmasq -C /tmp/eviltwin"
pkill -f aireplay-ng
rm -f /etc/nginx/sites-enabled/evil
nginx -t >/dev/null 2>&1 && systemctl reload nginx
airmon-ng stop wlan0mon >/dev/null 2>&1
airmon-ng stop wlan1mon >/dev/null 2>&1
ip addr flush dev wlan0 2>/dev/null
ip addr flush dev wlan1 2>/dev/null
ok "teardown complete"
