# Lilium Mobile

The phone and tablet shell of Lilium DE, as a [Solium](https://github.com/Lilium-Linux/solium)
configuration: Lua policy, QML scenes and effect files, with no code in the
compositor of its own. Developed on a Surface Pro 7 (tablet profile) and in a
nested Solium on the desktop.

## What it is

- **Launcher**: every installed application in a paged grid, a dock, a status
  bar; a launch grows the window out of its icon, iPad style
  (`mobile/effects/mobile-flight`).
- **Gestures** (`mobile/lua/mobile/policy.lua`, `mobile/lua/kinetics.lua`): up
  from the bottom centre and released quickly goes home, the window following the
  finger into its icon; held, it opens Recents. From the home screen the same
  swipe held opens Recents.
- **Recents**: the open windows as cards, rounded by their present
  (`mobile/effects/mobile-card`, which also draws their shadow); tap to open one,
  flick up to close it.
- **Shade**: quick settings.
- **Pane styles** (`mobile/qml/panes`): `mobile` (Recents' title above each card)
  and `mobile-flat` (an application on screen); the `icon` layer is what a window
  turns into as it flies to its launcher icon.

Settings live in `mobile/lua/mobile/config.lua`. `SOLIUM_MOBILE_PROFILE` picks
`phone`, `tablet` or `auto`; `SOLIUM_MOBILE_PACE` slows every flight evenly (1
is the iPad's timing); `SOLIUM_MOBILE_FINGER=1` shows a touch overlay for
testing.

## Install and run

Build Solium (its `stage`), then:

    ./install.sh /path/to/solium/target/release/solium /path/to/solium [new-prefix]

It installs into a new private directory under `~/.local/opt/` and checks the
configuration there. From a text console (not a desktop terminal, not SSH):

    PREFIX/run-mobile.sh

Each session's log and frame trace go to `PREFIX/state/runs/`.

## Developing

- `tests/policy.lua`: the policy against a stub `sol`, without a compositor:
  `lua tests/policy.lua` from this directory.
- `tools/`: scripted touch sequences for a nested Solium (`SOLIUM_TOUCH_AT`):
  `slowdemo.py` (open and send home), `recentsdemo.py` (Recents and closing),
  `cardtest.py` (cards, opening one, the home-screen swipe). Each prints the
  touch string on its first line.
