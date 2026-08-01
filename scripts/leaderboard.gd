extends Node

## Leaderboard submission, isolated behind one seam.
##
## The game is fully playable offline and must stay that way: every call here
## degrades to a no-op when Play Games Services is missing, which is the case
## in the editor, on desktop, and on any build where the plugin or the Play
## Console side has not been set up. Nothing in the game may branch on whether
## a leaderboard exists — it either submits or it quietly doesn't.
##
## LINKS
##   Play Console                https://play.google.com/console
##   PGS console setup           https://developer.android.com/games/pgs/console/setup
##   Enabling testers            https://developer.android.com/games/pgs/test
##   Troubleshooting sign-in     https://developer.android.com/games/pgs/android/troubleshooting
##   Godot 4 plugin              https://github.com/godot-sdk-integrations/godot-play-game-services
##
## TO FINISH THE INTEGRATION (all of this is Play Console work, not code):
##   1. Play Console -> Play Games Services -> set up a new game, link this app
##      (com.metatools.orbits).
##   2. Add an OAuth2 credential for the app; it needs the SHA-1 of the key the
##      build is signed with. For internal testing that is the upload key made
##      by tools/make-upload-key.sh:
##        keytool -list -v -keystore <keystore> -alias <alias> | grep SHA1
##      For the key built on 2026-08-01 that fingerprint is:
##        11:20:25:6A:D3:D1:F4:8D:C8:F3:C4:F7:72:B2:F0:E5:75:4D:C9:77
##      If you enable Play App Signing, Google re-signs the upload; the OAuth
##      client must then use the APP SIGNING SHA-1 shown in Play Console, not
##      this one. Getting this wrong is the usual cause of silent sign-in
##      failure.
##   3. Create a leaderboard ("Total Score", higher is better, integer) and copy
##      its ID into LEADERBOARD_ID below.
##   4. Add your testers to the Play Games Services testers list — this is a
##      separate list from the internal-testing track, and sign-in silently
##      fails for anyone not on it.
##   5. Install the godot-play-game-services plugin into android/plugins/ and
##      rebuild. SINGLETON_NAME below must match the plugin's singleton.
##
## Until step 5 lands, is_available() is false and the game behaves exactly as
## it does today.

const SINGLETON_NAME := "GodotPlayGameServices"

## Replace with the ID from Play Console (looks like "CgkI...").
const LEADERBOARD_ID := ""

var _service: Object = null
var _signed_in := false
var _pending_score := -1


func _ready() -> void:
	if not Engine.has_singleton(SINGLETON_NAME):
		return
	_service = Engine.get_singleton(SINGLETON_NAME)
	_connect_if_present("sign_in_success", _on_sign_in_success)
	_connect_if_present("sign_in_failed", _on_sign_in_failed)
	_call_if_present("sign_in")


func is_available() -> bool:
	return _service != null and _signed_in and not LEADERBOARD_ID.is_empty()


## Submit the player's running total. Safe to call on every win; the service
## keeps the best value, and a score that arrives before sign-in completes is
## held and sent once the session is up.
func submit(total_score: int) -> void:
	if total_score <= 0:
		return
	if not is_available():
		_pending_score = maxi(_pending_score, total_score)
		return
	_call_if_present("submit_leaderboard_score", [LEADERBOARD_ID, total_score])


## Opens the native leaderboard UI. Returns false if it could not be shown, so
## the caller can say something useful instead of appearing to do nothing.
func show_leaderboard() -> bool:
	if not is_available():
		return false
	return _call_if_present("show_leaderboard", [LEADERBOARD_ID])


func _on_sign_in_success(_account = null) -> void:
	_signed_in = true
	if _pending_score > 0:
		var held := _pending_score
		_pending_score = -1
		submit(held)


func _on_sign_in_failed(_error = null) -> void:
	_signed_in = false


# The plugin's exact API has changed across its releases, so every call is
# probed first. A missing method must never take the game down with it.

func _call_if_present(method: String, args: Array = []) -> bool:
	if _service == null or not _service.has_method(method):
		return false
	_service.callv(method, args)
	return true


func _connect_if_present(signal_name: String, target: Callable) -> void:
	if _service == null or not _service.has_signal(signal_name):
		return
	if not _service.is_connected(signal_name, target):
		_service.connect(signal_name, target)
