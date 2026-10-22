#!/usr/bin/env bash
# A traced Solium session from a text console, for testing on a device: the
# log and the frame trace go to ${XDG_STATE_HOME:-~/.local/state}/lilium-mobile/runs/<when>/.
#   tools/run-tty.sh [path/to/solium]      (default: solium on PATH)
# The configuration is whatever ${XDG_CONFIG_HOME:-~/.config}/solium is: run
# install.sh first. Capped at SOLIUM_MEMORY (3G) and 30 minutes.
set -euo pipefail
solium=${1:-$(command -v solium || true)}
[[ -n $solium && -x $solium ]] || { echo 'Give the Solium binary to run, or put solium on PATH.' >&2; exit 2; }
[[ -z ${WAYLAND_DISPLAY:-} ]] || { echo 'Run it from a text console, not inside a desktop.' >&2; exit 2; }
[[ $(tty 2>/dev/null || true) =~ ^/dev/tty[0-9]+$ ]] || { echo 'Run it on the device text console yourself, not through SSH.' >&2; exit 2; }
[[ -n ${XDG_RUNTIME_DIR:-} && -d $XDG_RUNTIME_DIR ]] || { echo 'Log into the console first so XDG_RUNTIME_DIR is set.' >&2; exit 2; }
# A console login may not include Flatpak's desktop-entry export directories.
export XDG_DATA_DIRS="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}:$HOME/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share"
config="${XDG_CONFIG_HOME:-$HOME/.config}/solium"
logs="${XDG_STATE_HOME:-$HOME/.local/state}/lilium-mobile/runs/$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p -- "$logs"
{
    date --iso-8601=seconds
    printf 'solium %s\n' "$solium"; sha256sum -- "$solium"
    printf 'config %s (%s)\n' "$(readlink -f -- "$config")" "$(git -C "$config" rev-parse --short HEAD 2>/dev/null || echo '?')"
    uname -a
} >"$logs/build.txt"
printf 'Swipe up from the bottom centre: quick = Home, held = Recents. Super+Shift+Q quits.\nLogs: %s\n' "$logs"
set +e
systemd-run --user --scope --quiet -p "MemoryMax=${SOLIUM_MEMORY:-3G}" -p MemorySwapMax=0 \
    timeout --foreground -k 10 -s TERM 1800 env SOLIUM_TRACE="$logs/trace.jsonl" RUST_LOG=solium=info \
    "$solium" --tty 2>&1 | tee "$logs/session.log"
status=${PIPESTATUS[0]}
set -e
printf '%s\n' "$status" >"$logs/exit-status"
printf 'Session ended (%s). Logs: %s\n' "$status" "$logs"
exit "$status"
