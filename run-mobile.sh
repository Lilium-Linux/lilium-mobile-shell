#!/usr/bin/env bash
set -euo pipefail
surface_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
surface_runner=${SOLIUM_QML_RUNNER:-}
if [[ -z $surface_runner ]]; then
    for candidate in "$surface_root/bin/qml" /usr/lib64/qt6/bin/qml /usr/lib/qt6/bin/qml qml6 qml-qt6 qml; do
        if command -v "$candidate" >/dev/null 2>&1; then surface_runner=$(command -v "$candidate"); break; fi
    done
fi
[[ -n $surface_runner && -x $surface_runner ]] || { echo 'Qt 6 qml runner is missing; set SOLIUM_QML_RUNNER to its path.' >&2; exit 2; }
export SOLIUM_SURFACE_ROOT=$surface_root SOLIUM_QML_RUNNER=$surface_runner
export SOLIUM_LUA_INIT="$surface_root/init.lua"
export XDG_CONFIG_HOME="$surface_root/config" XDG_STATE_HOME="$surface_root/state"
export SOLIUM_MOBILE_PROFILE=${SOLIUM_MOBILE_PROFILE:-tablet}
# A TTY login may not include Flatpak's desktop-entry export directories.
export XDG_DATA_DIRS="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}:$HOME/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share"
unset SOLIUM_TOUCH_AT SOLIUM_TRIGGER_AT SOLIUM_KEY_AT SOLIUM_CLICK_AT SOLIUM_DRAG_AT
mkdir -p "$XDG_STATE_HOME"
if [[ ${1:-} == --check ]]; then exec "$surface_root/bin/solium" --check; fi
[[ $# == 0 ]] || { echo 'Usage: run-mobile.sh [--check]' >&2; exit 2; }
[[ -z ${WAYLAND_DISPLAY:-} ]] || { echo 'Run from a logged-in free TTY, not a desktop terminal.' >&2; exit 2; }
[[ $(tty 2>/dev/null || true) =~ ^/dev/tty[0-9]+$ ]] || { echo 'Run this command on the Surface TTY yourself, not through SSH.' >&2; exit 2; }
[[ -n ${XDG_RUNTIME_DIR:-} && -d $XDG_RUNTIME_DIR ]] || { echo 'Log into the TTY first so XDG_RUNTIME_DIR is set.' >&2; exit 2; }
command -v systemd-run >/dev/null
command -v timeout >/dev/null
surface_logs="$surface_root/state/runs/$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$surface_logs"
{
    date --iso-8601=seconds
    cat "$surface_root/STAGE_REVISION"
    sha256sum "$surface_root/bin/solium"
    uname -a
    printf 'qml_runner=%s terminal=%s\n' "$surface_runner" "$(tty)"
} >"$surface_logs/build.txt"
printf 'Navigation bar hidden. Swipe up from the bottom centre: slow = Recents, fast = Home.\n'
printf 'Super+H Home; Super+Space Recents; Super+B Back; Super+Shift+Q quit.\n'
printf 'Logs: %s\n' "$surface_logs"
set +e
systemd-run --user --scope --quiet -p "MemoryMax=${SOLIUM_SURFACE_MEMORY:-3G}" -p MemorySwapMax=0 \
    timeout --foreground -k 10 -s TERM 1800 env SOLIUM_TRACE="$surface_logs/trace.jsonl" RUST_LOG=solium=info \
    "$surface_root/bin/solium" --tty 2>&1 | tee "$surface_logs/session.log"
surface_status=${PIPESTATUS[0]}
set -e
printf '%s\n' "$surface_status" >"$surface_logs/exit-status"
printf 'Session ended (%s). Logs: %s\n' "$surface_status" "$surface_logs"
exit "$surface_status"
