# Lilium Mobile

A phone and tablet shell for [Solium](https://github.com/Lilium-Linux/solium),
the Wayland compositor. It is a Solium configuration: Lua policy, QML scenes
and effect files, with no code of its own in the compositor. It is developed on
a Surface Pro 7 in tablet mode, and in a nested Solium on the desktop.

**Early preview.** It runs every day on that Surface, but it is young. Read
[What is missing](#what-is-missing) before you put it on a device you rely on.

Community: [Solium on Discord](https://discord.gg/ATQNfHHvFa).

## What it does

- **Home screen:** every installed application in a paged grid, with a dock
  and a status bar. Opening an app grows its window out of its icon, as on an
  iPad (`effects/mobile-flight`).
- **Gestures** (`mobile/policy.lua`, `kinetics.lua`):
  - A swipe up from the bottom centre, let go quickly, goes home; the window
    follows the finger into its icon.
  - The same swipe, held, opens Recents, from an app or from the home screen.
- **Recents:** the open windows as cards with rounded corners and a shadow
  (`effects/mobile-card`). Tap one to open it, flick it up to close it.
- **Control Center** (`qml/mobile/ControlCenter.qml`): pulled down from the
  right of the top edge, following the finger, as on an iPad. Wi-Fi,
  Bluetooth, airplane mode, brightness, volume, now playing, split screen,
  appearance and a screenshot. The status bar's clock fades out and its Wi-Fi
  and battery move into the panel as it comes down.
- **Lock:** pulled down from the left of the top edge, the clock side. Solium's
  own lock screen follows the finger and locks when you let go past a third of
  the screen. You unlock with your account password.
- **Apps put away:** an app you leave is minimized: it holds no keyboard and
  is not drawn, and Recents still shows it.
- **Icons:** the [WhiteSur](https://github.com/vinceliuice/WhiteSur-icon-theme)
  application icons, bundled in `icons/WhiteSur`, falling back to the system
  icon theme for apps WhiteSur does not cover (`qml/icons.js`).
- **Pane styles** (`qml/panes`): `mobile`, with Recents' title above each card,
  and `mobile-flat`, for an app on screen. Their `icon` layer is what a window
  turns into as it flies home.

## What you need

- **Solium, built from its `stage` branch.** The lock, minimizing and the
  frame-pacing fix need Solium changes that are on their way into `stage`.
  On an older Solium the shell still runs, without those features.
- **For the Control Center's controls:** NetworkManager (`nmcli`), BlueZ
  (`bluetoothctl`), PipeWire (`wpctl`), `playerctl`, and `grim` for
  screenshots.
- **For the lock to check your password:** the PAM file Solium installs as
  `/etc/pam.d/solium`. `solium --check` says whether it is there.

## Install

This folder *is* a Solium configuration, laid out as `~/.config/solium`:
`init.lua` is the entry point, the Lua modules sit beside it (`mobile/`,
`kinetics.lua`), scenes and pane styles are in `qml/`, and effects are in
`effects/`.

    ./install.sh

This links `${XDG_CONFIG_HOME:-~/.config}/solium` to this folder. A
configuration already there is moved aside, never deleted. If Solium is on
your `PATH`, the script then checks the configuration with `solium --check`.

Start Solium as usual, `solium --tty` from a text console. For a session that
records its log and frame trace in `~/.local/state/lilium-mobile/runs/`:

    tools/run-tty.sh [path/to/solium]

## Settings

Settings live in `mobile/config.lua`. Some environment variables help too:

- `SOLIUM_MOBILE_PROFILE`: `phone`, `tablet` or `auto`.
- `SOLIUM_MOBILE_PACE`: slows every animation evenly; 1 is the iPad's timing.
- `SOLIUM_MOBILE_FINGER=1`: draws a touch overlay, for testing.
- `LILIUM_MOBILE_DRY_RUN=1`: the Control Center changes nothing on the
  machine, for a nested test.

## What is missing

- **No on-screen keyboard.** Without a keyboard attached you cannot type,
  including your password at the lock (unless it is all digits).
- **No screen rotation.**
- **No PIN** for the lock. The account password is the only way in.
- The Control Center is still being tuned against the iPad's.

## Developing

- `tests/policy.lua`: the policy against a stub `sol`, without a compositor.
  Run `lua5.4 tests/policy.lua` from this folder. It needs Lua 5.4, the
  version Solium embeds; LuaJIT is 5.1 and lacks `math.tointeger`.
- `tools/`: scripted touch sequences for a nested Solium (`SOLIUM_TOUCH_AT`).
  Each script prints its touch string on the first line.
  - `slowdemo.py`: open an app and send it home.
  - `recentsdemo.py`: Recents, and closing a card.
  - `cardtest.py`: cards, opening one, and the home-screen swipe.
- `tools/update-whitesur.sh`: refreshes `icons/WhiteSur` from a pinned
  WhiteSur release.

## License

GPL-3.0-only (`LICENSE`), as Solium is. The bundled icons in `icons/WhiteSur`
are WhiteSur's, by Vince Liuice and its contributors, also under GPL-3.0. See
`icons/WhiteSur/README.md`, `COPYING` and `AUTHORS`.
