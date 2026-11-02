#!/usr/bin/env bash
# recon.sh — Laptop B. Put adapter into monitor mode and scan for targets.
# usage: sudo ./scripts/recon.sh [iface]
source "$(dirname "$0")/common.sh"
need_root
need_cmds airmon-ng airodump-ng iw

IF="${1:-wlan0}"
info "monitor mode on $IF"
airmon-ng check kill >/dev/null 2>&1 || true
airmon-ng start "$IF" >/dev/null 2>&1 || true
MON="${IF}mon"
iw dev "$MON" info >/dev/null 2>&1 || MON="$IF"
ok "monitor iface: $MON"
info "scanning — ctrl-c when you have your target's BSSID/ESSID/CH"
airodump-ng "$MON"
warn "fill TARGET_SSID / TARGET_BSSID / TARGET_CH in $ENV_FILE"
warn "when done: airmon-ng stop $MON"
