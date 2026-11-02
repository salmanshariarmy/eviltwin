#!/usr/bin/env bash
# common.sh — shared helpers, sourced by the other scripts
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$REPO_ROOT/config/eviltwin.env}"

c() { printf '\033[%sm%s\033[0m\n' "$1" "$2"; }
info()  { c '1;36' "[*] $*"; }
ok()    { c '1;32' "[+] $*"; }
warn()  { c '1;33' "[!] $*"; }
die()   { c '1;31' "[x] $*" >&2; exit 1; }

need_root() { [[ $EUID -eq 0 ]] || die "run as root"; }

load_env() {
  [[ -f "$ENV_FILE" ]] || die "missing $ENV_FILE — copy config/eviltwin.env.example"
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  : "${TARGET_SSID:?TARGET_SSID unset}"
  : "${TARGET_BSSID:?TARGET_BSSID unset}"
  : "${TARGET_CH:?TARGET_CH unset}"
}

need_cmds() {
  local miss=()
  for t in "$@"; do
    command -v "$t" >/dev/null 2>&1 || miss+=("$t")
  done
  ((${#miss[@]} == 0)) || die "missing: ${miss[*]} — apt install hostapd dnsmasq nginx php-fpm aircrack-ng iw"
}
