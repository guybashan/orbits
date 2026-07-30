# Orbits

A sliding-ball puzzle for Android. Each level gives you a grid of coloured
rings and a scatter of balls; slide balls into adjacent empty rings until every
ball sits on a ring of its own colour.

Built with Godot 4.6 (Compatibility renderer, portrait, 720×1280 base).

## How the puzzle works

Every level is defined only by its **solved** state. The starting layout is
produced by walking backwards from that solved state with `depth` random legal
moves (`Levels.generate`). Two things fall out of this:

- **Every level is guaranteed solvable.** There is no way to generate a
  scattered board that can't be reassembled, because the scatter *is* a
  sequence of legal moves played in reverse.
- **Par is honest.** `depth` is a move count that provably solves the level, so
  it can be used directly as the 3-star threshold.

The shuffle is a self-avoiding walk — it never revisits a state it has already
produced, including the solved one. That stops it handing the player a board
that is already finished, and stops shuffle steps cancelling each other out.

`tests/test_levels.gd` enforces this: for all 35 levels it replays the shuffle
backwards and asserts the board lands exactly on the goal pattern.

## Layout

```
scripts/
  levels.gd        level bank + start-state generation (no engine dependencies)
  board.gd         the 3D grid: sockets, balls, moves, correctness
  ball.gd          palette and per-ball visual state
  game_main.gd     play screen: input, undo, scoring, win flow
  game_data.gd     autoload — save file and settings
  audio.gd         autoload — SFX pool, music, haptics
  goal_view.gd     2D goal thumbnail
  star_row.gd      drawn star ratings
  level_select.gd  level grid
  menu.gd          title screen
scenes/
  menu.tscn        boot scene
  main.tscn        play screen
  level_select.tscn
  ui_theme.tres    shared theme
tools/             release scripts
tests/             headless test + screenshot harness
```

Adding a level is one entry in `Levels.LEVELS` — the level select grid, star
totals and unlock chain all size themselves off `Levels.count()`.

## Running the tests

```bash
godot --headless --script tests/test_levels.gd
```

Verifies every level's pattern is well formed, its start state is reachable
back to the goal, and solving in par awards 3 stars.

```bash
godot --script tests/test_win_flow.gd --resolution 720x1280 -- 0
```

Boots the play screen, solves the level by replaying the shuffle backwards, and
checks the win sequence, star award and save persistence. Pass a level index
(0-based); add an output path to also save a screenshot.

## Releasing to Play Console internal testing

The export preset is configured for a Gradle build producing a signed `.aab`:
min SDK 24, target SDK 35, `arm64-v8a` + `armeabi-v7a`, adaptive launcher icons,
and `VIBRATE` as the only permission.

**One-time setup.** Create the upload key (keytool prompts for the password —
it is never stored in this repo):

```bash
./tools/make-upload-key.sh
```

Back the resulting keystore up somewhere durable. Losing it means you cannot
ship an update to the same Play listing.

**Every build.** Export the three variables the script printed, then:

```bash
VERSION_CODE=2 VERSION_NAME=1.0.1 ./tools/build-release.sh
```

Play rejects an upload whose `versionCode` it has already seen, so raise it for
each new internal-test build. The `.aab` lands in `build/`; upload it under
**Testing → Internal testing → Create new release**.

If the Android build template is ever missing (it is gitignored — it is
generated, not source):

```bash
godot --headless --install-android-build-template --export-debug Android build/orbits-debug.aab
```
