extends Node

## Autoloaded audio + haptics. Owns a small pool of players so overlapping
## effects never cut each other off, and reads its on/off state from GameData.

const SFX_POOL_SIZE := 8

const STREAMS := {
	"move": preload("res://sounds/move.wav"),
	"bounce": preload("res://sounds/bounce.wav"),
	"lock": preload("res://sounds/lock.wav"),
	"ui": preload("res://sounds/ui.wav"),
	"star": preload("res://sounds/star.wav"),
	"win": preload("res://sounds/win.wav"),
}

## Trimmed against each clip's measured RMS rather than by eye. `move` fires on
## every single move, so it sits well under the rest of the set.
const VOLUMES := {
	"move": -13.0,
	"bounce": -14.0,
	"lock": -9.0,
	"ui": -15.0,
	"star": -8.0,
	"win": -5.0,
}

const MUSIC_VOLUME := -17.0

## Five tracks, escalating. Which one plays is a function of how far through
## the game the player is, so the score tightens as the boards do.
const MUSIC_TRACKS := [
	preload("res://sounds/music_1.wav"),
	preload("res://sounds/music_2.wav"),
	preload("res://sounds/music_3.wav"),
	preload("res://sounds/music_4.wav"),
	preload("res://sounds/music_5.wav"),
]

const MUSIC_CROSSFADE := 1.4
const MUSIC_SILENT_DB := -40.0

var _sfx_players: Array[AudioStreamPlayer] = []
var _next_player := 0
## Two players so tracks can cross-fade; a hard cut between pieces is jarring
## right at the moment the player has just finished a level.
var _music_players: Array[AudioStreamPlayer] = []
var _active_music := 0
var _current_track := -1
var _fade: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_sfx_players.append(player)

	for track in MUSIC_TRACKS:
		var wav: AudioStreamWAV = track
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		# Loop end must be set explicitly in frames. Leaving it at 0 is not a
		# reliable way to say "end of clip", and a wrong loop point is instantly
		# audible on something that repeats every twenty seconds.
		var bytes_per_frame := 2 * (2 if wav.stereo else 1)  # 16-bit samples
		wav.loop_end = wav.data.size() / bytes_per_frame

	for i in 2:
		var player := AudioStreamPlayer.new()
		player.volume_db = MUSIC_SILENT_DB
		add_child(player)
		_music_players.append(player)


func play(name: String, pitch_variance: float = 0.0) -> void:
	if not GameData.sfx_enabled:
		return
	var stream: AudioStream = STREAMS.get(name)
	if stream == null:
		return

	var player := _sfx_players[_next_player]
	_next_player = (_next_player + 1) % _sfx_players.size()

	player.stream = stream
	player.volume_db = VOLUMES.get(name, -10.0)
	player.pitch_scale = 1.0 + randf_range(-pitch_variance, pitch_variance)
	player.play()


## Major pentatonic, in semitones. Every degree is consonant with every other,
## so a run of placements sounds like a phrase no matter which order the player
## fills the board in — there is no combination that can sour.
const LOCK_LADDER := [0, 2, 4, 7, 9, 12, 14, 16]


## A ball landing on its socket. `streak` is how many placements in a row the
## player has made; the pitch climbs the ladder and wraps, turning a good run
## into a rising figure instead of the same chime twenty times.
func play_lock(streak: int) -> void:
	if not GameData.sfx_enabled:
		return
	var semitones: int = LOCK_LADDER[maxi(streak, 0) % LOCK_LADDER.size()]
	var player := _sfx_players[_next_player]
	_next_player = (_next_player + 1) % _sfx_players.size()
	player.stream = STREAMS["lock"]
	player.volume_db = VOLUMES["lock"]
	player.pitch_scale = pow(2.0, semitones / 12.0)
	player.play()


## Plays a rising run of star chimes, one per star earned.
func play_star_run(count: int) -> void:
	for i in count:
		var delay := 0.18 * i
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			if not GameData.sfx_enabled:
				return
			var player := _sfx_players[_next_player]
			_next_player = (_next_player + 1) % _sfx_players.size()
			player.stream = STREAMS["star"]
			player.volume_db = VOLUMES["star"]
			player.pitch_scale = 1.0 + 0.18 * i
			player.play()
		)


## Pick the track for a level. Bands are proportional to the size of the level
## bank, so adding levels re-spreads the escalation instead of leaving every
## new level on the final track.
func track_for_level(index: int) -> int:
	var total: int = maxi(Levels.count(), 1)
	var band := int(float(index) / float(total) * MUSIC_TRACKS.size())
	return clampi(band, 0, MUSIC_TRACKS.size() - 1)


func set_music_for_level(index: int) -> void:
	play_track(track_for_level(index))


func play_track(track: int) -> void:
	track = clampi(track, 0, MUSIC_TRACKS.size() - 1)
	if track == _current_track:
		update_music()
		return
	_current_track = track

	if not GameData.music_enabled:
		return

	var outgoing := _music_players[_active_music]
	_active_music = 1 - _active_music
	var incoming := _music_players[_active_music]

	incoming.stream = MUSIC_TRACKS[track]
	incoming.volume_db = MUSIC_SILENT_DB
	incoming.play()

	if _fade and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.set_parallel(true)
	_fade.tween_property(incoming, "volume_db", MUSIC_VOLUME, MUSIC_CROSSFADE)
	if outgoing.playing:
		_fade.tween_property(outgoing, "volume_db", MUSIC_SILENT_DB, MUSIC_CROSSFADE)
		_fade.chain().tween_callback(outgoing.stop)


func update_music() -> void:
	var player := _music_players[_active_music]
	if GameData.music_enabled:
		if _current_track < 0:
			_current_track = 0
		if not player.playing:
			player.stream = MUSIC_TRACKS[_current_track]
			player.volume_db = MUSIC_VOLUME
			player.play()
	else:
		for p in _music_players:
			p.stop()


func haptic(milliseconds: int = 18) -> void:
	if not GameData.haptics_enabled:
		return
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(milliseconds)
