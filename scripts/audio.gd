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

var _sfx_players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _music_player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_sfx_players.append(player)

	_music_player = AudioStreamPlayer.new()
	var music: AudioStreamWAV = preload("res://sounds/music.wav")
	music.loop_mode = AudioStreamWAV.LOOP_FORWARD
	music.loop_begin = 0
	# Set the loop end explicitly in frames. Leaving it at 0 is not a reliable
	# way to say "the end of the clip", and a wrong loop point is instantly
	# audible on a track that repeats every 23 seconds.
	var bytes_per_frame := 2 * (2 if music.stereo else 1)  # 16-bit samples
	music.loop_end = music.data.size() / bytes_per_frame
	_music_player.stream = music
	_music_player.volume_db = MUSIC_VOLUME
	add_child(_music_player)


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


func update_music() -> void:
	if GameData.music_enabled:
		if not _music_player.playing:
			_music_player.play()
	elif _music_player.playing:
		_music_player.stop()


func haptic(milliseconds: int = 18) -> void:
	if not GameData.haptics_enabled:
		return
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(milliseconds)
