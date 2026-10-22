#!/usr/bin/env python3
# Touch script for the slow Recents/close demo: opens six installed apps (each
# sent home with the recorded flick), drags the last one into Recents with a
# swipe-and-hold, opens a card, goes back to Recents, closes four cards with
# upward flicks, opens one of the two left and sends it home.
# Prints SOLIUM_TOUCH_AT on line 1 and the end time (ms) on line 2.

ICONS = {  # tablet grid, 14 columns, rows 112 px (never Claude at 636,126)
    "dolphin": (1182, 126), "kcalc": (200, 350), "elisa": (1400, 126),
    "kwrite": (855, 462), "gwenview": (964, 238), "kcharselect": (309, 350),
}
OPEN = ["dolphin", "kcalc", "elisa", "kwrite", "gwenview", "kcharselect"]

# Recents on the 1600x900 nested output (policy.lua card_metrics): three
# columns of two, cards 493x268 at x = 32 + 521.3 * column, y = 90 + 368 * row;
# card n (1 = most recent) is column (n-1)//2, row (n-1)%2.
def card(n):
    column, row = (n - 1) // 2, (n - 1) % 2
    return 32 + 521.3 * column + 246.5, 90 + 368 * row + 134

SWIPE = [line.strip().split(":") for line in open(__file__.rsplit("/", 1)[0] + "/swipe-home.txt") if line.strip()]
events, t = [], 3000

def ev(at, kind, x, y):
    events.append(f"{at}:{kind}:0:{x:.1f},{y:.1f}")

def tap(x, y):
    ev(t, "down", x, y); ev(t + 55, "up", x, y)

def swipe_home():
    base = int(SWIPE[0][0])
    for ms, kind, slot, pos in SWIPE:
        events.append(f"{t + int(ms) - base}:{kind}:{slot}:{pos}")

def swipe_to_recents():
    # Up from the bottom edge, slowing to a stop about a third of the way,
    # held still, released: no fling, so the window settles into its card.
    x0, y0, n = 800.0, 893.0, 90
    ev(t, "down", x0, y0)
    for i in range(1, n + 1):
        p = i / n
        e = 1 - (1 - p) ** 2.2
        ev(t + i * 8, "motion", x0 - 30 * p, y0 - 330 * e)
    end = t + n * 8
    for k in range(1, 6):
        ev(end + k * 40, "motion", x0 - 30, y0 - 330)
    ev(end + 240, "up", x0 - 30, y0 - 330)

def flick_card_up(n):
    x, y = card(n)
    ev(t, "down", x, y)
    for i in range(1, 19):
        p = i / 18
        ev(t + i * 8, "motion", x + 6 * p, y - 300 * p ** 1.5)
    ev(t + 18 * 8 + 8, "up", x + 6, y - 300)

for app in OPEN[:-1]:
    tap(*ICONS[app]); t += 2600
    swipe_home(); t += 1750
tap(*ICONS[OPEN[-1]]); t += 2800

swipe_to_recents(); t += 2600          # kcharselect becomes card 1 of six
tap(*card(5)); t += 2200               # kcalc opens from its card
swipe_to_recents(); t += 2600          # back: kcalc is card 1 now
for n in (6, 4, 2, 3):                 # close four, the grid closing up each time
    flick_card_up(n); t += 1700
tap(*card(2)); t += 2400               # open one of the two left
swipe_home(); t += 2200
print(";".join(events))
print(t)
