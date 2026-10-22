#!/usr/bin/env bash
# Install the mobile shell, with a Solium binary and that Solium's own QML, Lua
# and effects, into a new private user directory. No services, no login
# sessions, nothing outside the prefix.
#   install.sh /path/to/solium-binary /path/to/solium-checkout [new-prefix] [qml-runner]
# The checkout is the one the binary was built from: its crates/solium/{qml,lua,effects}
# are what the binary loads as its shipped defaults.
set -euo pipefail
shell_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
binary=${1:?Usage: install.sh /path/to/solium-binary /path/to/solium-checkout [new-prefix] [qml-runner]}
checkout=${2:?Usage: install.sh /path/to/solium-binary /path/to/solium-checkout [new-prefix] [qml-runner]}
qml_runner=${4:-}
[[ -x $binary ]] || { echo 'Provide an executable Solium binary.' >&2; exit 2; }
[[ -d $checkout/crates/solium/qml ]] || { echo 'Provide the Solium checkout the binary was built from.' >&2; exit 2; }
[[ -z $qml_runner || -x $qml_runner ]] || { echo 'The QML runner must be executable.' >&2; exit 2; }
engine=$(git -C "$checkout" rev-parse --short HEAD 2>/dev/null || echo unknown)
shell=$(git -C "$shell_root" rev-parse --short HEAD 2>/dev/null || echo unknown)
prefix=${3:-$HOME/.local/opt/lilium-mobile-$shell-solium-$engine}
[[ $prefix == /* && ! -e $prefix ]] || { echo 'The destination must be an absolute, new directory.' >&2; exit 2; }
mkdir -p "$(dirname "$prefix")"
temp=$(mktemp -d "$(dirname "$prefix")/.lilium-mobile-install.XXXXXX")
trap 'rm -rf -- "$temp"' EXIT
mkdir -p "$temp/bin" "$temp/share/solium" "$temp/config/solium/qml" "$temp/config/solium/effects"
for folder in qml lua effects; do
    cp -a "$checkout/crates/solium/$folder" "$temp/share/solium/$folder"
done
cp --reflink=auto "$binary" "$temp/bin/solium"
chmod 755 "$temp/bin/solium"
if [[ -n $qml_runner ]]; then cp "$qml_runner" "$temp/bin/qml"; chmod 755 "$temp/bin/qml"; fi
cp -a "$shell_root/mobile" "$temp/mobile"
cp -a "$shell_root/mobile/qml/." "$temp/config/solium/qml/"
cp -a "$shell_root/mobile/effects/." "$temp/config/solium/effects/"
cp "$shell_root/init.lua" "$shell_root/run-mobile.sh" "$shell_root/README.md" "$temp/"
printf 'lilium-mobile %s on Solium %s\n' "$shell" "$engine" > "$temp/STAGE_REVISION"
chmod 755 "$temp/run-mobile.sh"
"$temp/run-mobile.sh" --check
mv -- "$temp" "$prefix"
trap - EXIT
printf 'Installed: %s\nFrom a text console run:\n  %s/run-mobile.sh\n' "$prefix" "$prefix"
