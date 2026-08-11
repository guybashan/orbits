# Play Store listing — Orbits

Everything Google asks for in the listing, ready to paste. Character limits are
Google's and are checked in the counts below.

---

## App name (30 max)

```
Orbits: Slide Colour Puzzle
```

**26 characters.** "Orbits" alone is crowded on Play — several established
gravity games own that word, and all of them are physics toys, which sets the
wrong expectation for a sliding puzzle. The subtitle both disambiguates and
carries the two words people actually search for.

---

## Short description (80 max)

```
Slide the balls, match every colour to its ring. 100 levels, no timers, no ads.
```

**78 characters.**

---

## Full description (4000 max)

```
Every board is a pattern waiting to be rebuilt.

Slide a ball into the empty space next to it. Keep going until every colour
sits in its matching ring. That is the whole game — no combos to memorise, no
energy meter, no timer counting down at you.

The catch is the empty space. There is only ever a little of it, and every move
you make moves it too. Late boards leave you a single gap in sixty-four, and
finding the order that gets everything home is the puzzle.

100 HAND-TUNED LEVELS
The climb is deliberate. Level 1 is four balls on a 4x4 board and takes three
moves. Level 100 is sixty-three balls on an 8x8 board with one empty cell and
takes seventy. Every level in between is a measured step up — never a wall, and
never a plateau.

ALWAYS SOLVABLE
Every board is built by starting from the finished pattern and shuffling it
backwards. That means no level is ever impossible, and the move target you are
scored against is a route that genuinely exists. Beat it if you can find a
shorter one.

THE SAME GAME FOR EVERYONE
Boards are not random. Level 40 is the same forty-first puzzle for every player
on every device, so a score means something and a friend stuck on the same
board is stuck on your board.

PLAY IT YOUR WAY
Unlimited undo. Reset whenever. A hint when you want one. The clock does not
start until your first move, so studying the board costs nothing.

NO ADS. NO PURCHASES. NO ACCOUNT.
Nothing to buy, nothing to watch, nothing to sign into. It works offline, on a
plane, in a tunnel.

Score is a blend of how few moves you took and how quickly you found them, and
each level keeps your best, so a bad replay can never cost you what you earned.
```

**~1,480 characters.**

---

## Graphics

| Asset | Requirement | Status |
|---|---|---|
| App icon | 512×512 PNG | `assets/icons/icon_512.png` |
| Feature graphic | 1024×500 PNG | generated — see `store/feature_graphic.png` |
| Phone screenshots | 2–8, min 1080px | 5 at 1080×1920 in `store/screenshots/` |

Screenshots are captured from the running game with `tests/screenshot.gd`, so
they cannot drift from what ships.

---

## Categorisation

- **App or game:** Game
- **Category:** Puzzle
- **Tags:** Puzzle, Brain, Casual
- **Contact email:** guy.bashan@gmail.com

---

## Filed on 12 August 2026

Everything below the line was completed in Play Console and sent to Google for
review (14 changes, typically reviewed within 7 days): privacy policy URL,
sign-in details, ads, IARC content rating, target audience (13+), data safety
(no collection), government apps, financial features, health, advertising ID,
category (Game / Puzzle), and the closed-testing (alpha) release of 1.4.2 for
176 countries.

**Still open, and genuinely account-holder work: add 12+ testers to the closed
track (Closed testing → Testers → create an email list) and get them opted in
for 14 continuous days.**

## What only the account holder can do

These are Play Console forms tied to the developer account. They cannot be
filled in through the Publishing API, so they are not automatable:

1. **Content rating questionnaire (IARC).** Answer honestly — no violence, no
   user content, no data collection. Expect an "Everyone" rating.
2. **Data safety form.** This game collects and transmits **nothing**. There is
   no analytics SDK, no ad SDK, no crash reporter and no network code at all
   outside the unused leaderboard seam. Declare no data collected, no data
   shared.
3. **Privacy policy URL.** Required even when nothing is collected. A draft is
   in `store/privacy-policy.md` — it needs to be hosted at a public URL
   (GitHub Pages is enough) and the link pasted into Console.
4. **Target audience and content.** Not directed at children unless you choose
   to say so; note that declaring a child audience pulls in Families Policy
   obligations.
5. **App access.** Declare that all content is available without login.
6. **Closed testing.** If this developer account is a personal account created
   after November 2023, production access requires **12 testers opted in for 14
   continuous days** on a closed track. Internal testing does not satisfy it.
   This is a two-week floor on any public launch, so start it first.
