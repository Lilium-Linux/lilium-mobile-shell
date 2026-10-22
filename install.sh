#!/usr/bin/env bash
# Make this checkout your Solium configuration:
#   ${XDG_CONFIG_HOME:-~/.config}/solium -> this directory.
# A configuration already there is moved aside, never deleted.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
target="${XDG_CONFIG_HOME:-$HOME/.config}/solium"
if [[ -L $target && $(readlink -f -- "$target") == "$here" ]]; then
    echo "Already installed: $target -> $here"
elif [[ -e $target || -L $target ]]; then
    aside="$target.before-lilium-mobile.$(date +%Y%m%d-%H%M%S)"
    mv -- "$target" "$aside"
    echo "Your configuration was moved aside: $aside"
fi
mkdir -p -- "$(dirname -- "$target")"
[[ -L $target ]] || ln -s -- "$here" "$target"
echo "$target -> $here"
if command -v solium >/dev/null 2>&1; then solium --check; fi
