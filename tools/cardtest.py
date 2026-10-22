#!/usr/bin/env python3
# Three apps, into Recents under the finger, open a card, back, close one,
# home, then the swipe-and-hold from the home screen. Line 1 the touches,
# line 2 when Recents is first entered (ms), line 3 the end.
import os
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "recentsdemo.py")).read().split("for app in OPEN[:-1]:")[0])
marks = {}
for app in ["dolphin", "kcalc"]:
    tap(*ICONS[app]); t += 2600
    swipe_home(); t += 1750
tap(*ICONS["elisa"]); t += 2800
marks["recents"] = t
swipe_to_recents(); t += 2000
tap(*card(2)); t += 1800
swipe_to_recents(); t += 2000
flick_card_up(3); t += 1500
tap(1300, 700); t += 1500           # empty space beside the cards: home
marks["home"] = t
swipe_to_recents(); t += 2200       # from the home screen now
print(";".join(events)); print(marks["recents"]); print(marks["home"]); print(t)
