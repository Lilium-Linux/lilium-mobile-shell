#!/usr/bin/env python3
# Touch script for the slow open/go-home demo: taps an installed app's icon,
# lets it open, swipes up from the bottom edge with a human-like curve, and
# moves to the next app; a few apps are reopened right after going home.
# Prints SOLIUM_TOUCH_AT on line 1 and the end time (ms) on line 2.

ICONS = {  # tablet grid, 14 columns, rows 112 px (never Claude at 636,126)
    "dolphin": (1182, 126), "elisa": (1400, 126), "kcalc": (200, 350),
    "kcharselect": (309, 350), "gwenview": (964, 238), "kwrite": (855, 462),
    "kmines": (91, 462), "okular": (1182, 574), "konsole": (1291, 462),
}
SEQ = ["dolphin", "kcalc", "elisa", "kwrite", "dolphin", "gwenview",
       "kcharselect", "kcalc", "okular", "kmines", "konsole", "elisa"]

events, t = [], 3000

def tap(x, y):
    global t
    events.append(f"{t}:down:0:{x:.1f},{y:.1f}")
    events.append(f"{t + 55}:up:0:{x:.1f},{y:.1f}")

# The go-home flick recorded for the perf sequence (swipe-home.txt): a slow
# start that speeds up, drifting left, like a thumb. Replayed as it is.
SWIPE = [line.strip().split(":") for line in open(__file__.rsplit("/", 1)[0] + "/swipe-home.txt") if line.strip()]

def swipe_home():
    base = int(SWIPE[0][0])
    for ms, kind, slot, pos in SWIPE:
        events.append(f"{t + int(ms) - base}:{kind}:{slot}:{pos}")

prev = None
for i, app in enumerate(SEQ):
    x, y = ICONS[app]
    tap(x, y)
    # A first launch waits for the client; a reopen is immediate.
    t += 2600 if app not in SEQ[:i] else 1700
    swipe_home()
    t += 1750
print(";".join(events))
print(t)
