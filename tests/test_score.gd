extends SceneTree

## Scoring rules. Pure maths, no scene — fast enough to run on every change.
##   godot --headless --script tests/test_score.gd

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _init() -> void:
	var par := 20
	var budget := Score.time_budget(par)

	# A flawless run: at par, inside the time budget.
	var perfect := Score.for_level(par, par, budget)
	check(perfect == Score.best_possible(par),
		"a par clear inside budget should score the level maximum")

	# Beating par cannot score more than par — par is already full marks.
	check(Score.for_level(par - 5, par, budget) == perfect,
		"finishing under par should not exceed the maximum")

	# More moves must score strictly less.
	check(Score.for_level(par * 2, par, budget) < perfect, "double par should score less")
	check(Score.for_level(par * 2, par, budget) > 0, "a clumsy clear should still score")

	# Slower must score strictly less, and time must matter on its own.
	check(Score.for_level(par, par, budget * 3) < perfect, "a slow clear should score less")
	check(Score.for_level(par, par, budget * 3) > Score.for_level(par * 3, par, budget * 3),
		"moves should weigh more than time")

	# Monotonic in both inputs — no local optimum that rewards playing worse.
	var previous := perfect + 1
	for extra in range(0, 40, 4):
		var s := Score.for_level(par + extra, par, budget)
		check(s < previous, "score must fall as moves rise (at +%d)" % extra)
		previous = s

	previous = perfect + 1
	for factor in [1.0, 1.5, 2.0, 3.0, 5.0, 8.0]:
		var s := Score.for_level(par, par, budget * factor)
		check(s <= previous, "score must not rise as time rises (at x%.1f)" % factor)
		previous = s

	# Harder levels must be worth more, or the ranking rewards easy grinding.
	check(Score.best_possible(50) > Score.best_possible(3),
		"a par-50 level should be worth more than a par-3 level")

	# A perfect run on every level should be a sane headline number.
	# A perfect game should be a number a person can hold in their head. Linear
	# difficulty weighting put this at 248,666, which is why it is now rooted.
	var total := Score.best_possible_total()
	check(total > 20000 and total < 150000,
		"total possible score %d is outside a readable range" % total)

	# Hard levels must still pay meaningfully more, just not absurdly more.
	var spread := float(Score.best_possible(50)) / float(Score.best_possible(3))
	check(spread > 2.0 and spread < 6.0,
		"hardest/easiest payout ratio is %.1fx, want roughly 4x" % spread)

	# Degenerate inputs must not produce negative or absurd scores.
	check(Score.for_level(0, par, budget) == 0, "zero moves should score zero")
	check(Score.for_level(par, par, 0.0) == perfect, "an instant clear should cap, not overflow")
	check(Score.for_level(9999, par, 99999.0) >= 0, "a terrible run must not go negative")

	check(Score.format_time(0.0) == "0:00", "time format at zero")
	check(Score.format_time(65.4) == "1:05", "time format past a minute")
	check(Score.format_time(3599.0) == "59:59", "time format near an hour")

	if failures.is_empty():
		print("PASS — scoring is monotonic, bounded and difficulty-weighted")
		print("       max per level: par 3 -> %d pts, par 50 -> %d pts" % [
			Score.best_possible(3), Score.best_possible(50)])
		print("       perfect game: %d pts" % total)
		quit(0)
	for f in failures:
		print("FAIL: ", f)
	quit(1)
