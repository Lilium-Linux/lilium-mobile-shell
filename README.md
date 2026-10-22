# Lilium Mobile

The phone and tablet shell of Lilium DE, as a [Solium](https://github.com/Lilium-Linux/solium)
configuration: Lua policy, QML scenes and effect files, with no code in the
compositor of its own. Developed on a Surface Pro 7 (tablet profile) and in a
nested Solium on the desktop.

## What it is

- **Launcher**: every installed application in a paged grid, a dock, a status
  bar; a launch grows the window out of its icon, iPad style
  (`effects/mobile-flight`).
- **Gestures** (`mobile/policy.lua`, `kinetics.lua`): up
  from the bottom centre and released quickly goes home, the window following the
  finger into its icon; held, it opens Recents. From the home screen the same
  swipe held opens Recents.
- **Recents**: the open windows as cards, rounded by their present
  (`effects/mobile-card`, which also draws their shadow); tap to open one,
  flick up to close it.
- **Shade**: quick settings.
- **Pane styles** (`qml/panes`): `mobile` (Recents' title above each card)
  and `mobile-flat` (an application on screen); the `icon` layer is what a window
  turns into as it flies to its launcher icon.

Settings live in `mobile/config.lua`. `SOLIUM_MOBILE_PROFILE` picks
`phone`, `tablet` or `auto`; `SOLIUM_MOBILE_PACE` slows every flight evenly (1
is the iPad's timing); `SOLIUM_MOBILE_FINGER=1` shows a touch overlay for
testing.

## Install and run

This directory *is* a Solium configuration, laid out as `~/.config/solium`:
`init.lua` is the entry point, the Lua modules sit beside it (`mobile/`,
`kinetics.lua`), scenes and pane styles are in `qml/`, effect folders in
`effects/`. Solium needs nothing else to run it.

    ./install.sh

links `${XDG_CONFIG_HOME:-~/.config}/solium` to this checkout (a configuration
already there is moved aside), and checks it with `solium --check` when Solium
is on `PATH`. Then start Solium as usual, `solium --tty` from a text console.

For a traced test session on a device:

    tools/run-tty.sh [path/to/solium]

writes the log and frame trace to `~/.local/state/lilium-mobile/runs/`.

## Developing

- `tests/policy.lua`: the policy against a stub `sol`, without a compositor:
  `lua5.4 tests/policy.lua` from this directory (Lua 5.4, as Solium embeds;
  LuaJIT is 5.1 and lacks `math.tointeger`).
- `tools/`: scripted touch sequences for a nested Solium (`SOLIUM_TOUCH_AT`):
  `slowdemo.py` (open and send home), `recentsdemo.py` (Recents and closing),
  `cardtest.py` (cards, opening one, the home-screen swipe). Each prints the
  touch string on its first line.
