class_name Score
extends RefCounted

## Ranked scoring: how efficiently you solved it, and how quickly.
##
## Both halves are ratios against a budget rather than raw counts, so a player
## who plays well on an easy level cannot out-score a player who plays well on
## a hard one. The difficulty weight is par, which is a real measure of a
## level's size (see Levels.generate).
##
##   moves : full marks at or under par, falling off as you exceed it
##   time  : full marks inside the time budget, falling off beyond it
##
## Neither component can go negative, so a slow, clumsy clear still scores —
## it just scores badly. Nothing here reads the clock directly; elapsed time is
## passed in, which keeps it testable.

const MOVE_POINTS := 600.0
const TIME_POINTS := 400.0

## Seconds of thinking time allowed per par move before the time bonus decays.
const SECONDS_PER_PAR_MOVE := 4.0

## Par of the easiest level, so level 1 has a difficulty weight of ~1.
const DIFFICULTY_BASE := 3.0


static func time_budget(par: int) -> float:
	return SECONDS_PER_PAR_MOVE * float(par)


static func move_ratio(moves: int, par: int) -> float:
	if moves <= 0:
		return 0.0
	return clampf(float(par) / float(maxi(moves, par)), 0.0, 1.0)


static func time_ratio(seconds: float, par: int) -> float:
	var budget := time_budget(par)
	if budget <= 0.0:
		return 0.0
	return clampf(budget / maxf(seconds, budget), 0.0, 1.0)


static func difficulty(par: int) -> float:
	return float(par) / DIFFICULTY_BASE


static func for_level(moves: int, par: int, seconds: float) -> int:
	if moves <= 0:
		return 0
	var earned := MOVE_POINTS * move_ratio(moves, par) + TIME_POINTS * time_ratio(seconds, par)
	return int(round(earned * difficulty(par)))


## The most a level can be worth — a flawless clear inside the time budget.
static func best_possible(par: int) -> int:
	return int(round((MOVE_POINTS + TIME_POINTS) * difficulty(par)))


static func best_possible_total() -> int:
	var total := 0
	for index in Levels.count():
		total += best_possible(Levels.par(index))
	return total


## Split out for the win panel, so the player can see which half cost them.
static func breakdown(moves: int, par: int, seconds: float) -> Dictionary:
	var weight := difficulty(par)
	return {
		"moves": int(round(MOVE_POINTS * move_ratio(moves, par) * weight)),
		"time": int(round(TIME_POINTS * time_ratio(seconds, par) * weight)),
		"total": for_level(moves, par, seconds),
		"budget": time_budget(par),
	}


static func format_time(seconds: float) -> String:
	var whole := int(maxf(seconds, 0.0))
	return "%d:%02d" % [whole / 60, whole % 60]
