extends Node
## Pooled SFX + music playback, autoloaded as "SoundManager" (after SaveManager in
## project.godot's [autoload] order, since _ready() below reads SaveManager.sfx_on()/
## music_on() at boot). Preloads every WAV under res://audio/sfx and res://audio/music
## into a Dictionary, round-robins POOL_SIZE AudioStreamPlayers on the "SFX" bus for
## one-shots (no per-shot node allocation, even for a 0.05s-interval gun), and drives a
## single dedicated looping player on the "Music" bus.
##
## No default_bus_layout.tres exists in this project, and hand-authoring one risks
## import/format drift across editor versions and machines — the "SFX"/"Music" buses are
## created in code at _ready() instead, which works identically headless and in-editor.

## Every generated SFX id (scripts/gen_retro_audio.py in the home repo writes the WAVs).
const SFX_IDS: Array[String] = [
	"shot_pistol", "shot_smg", "shot_shotgun", "shot_rifle", "shot_sniper", "shot_heavy",
	"shot_special", "hit_enemy", "die_enemy", "explosion", "gem", "coin", "crate_win",
	"level_up", "ui_tap", "purchase", "dash", "purge", "player_hurt", "death_sting",
	"boss_roar", "dawn_sting",
]
const MUSIC_IDS: Array[String] = ["menu_loop", "run_loop"]

const POOL_SIZE := 8
const SFX_BUS := "SFX"
const MUSIC_BUS := "Music"

## Per-id minimum gap (ms) between plays, so a busy frame (a flame cone tagging ten
## enemies, a kill-chain) can't machine-gun the same one-shot. 0 = unthrottled.
const MIN_INTERVAL_MS := {
	"hit_enemy": 80,
	"die_enemy": 50,
	# The flamethrower's cone lands a successful _fire() 20x/s, which unthrottled
	# machine-guns the shot sound; ~8/s reads as a continuous spray instead. The Tesla
	# shares this id but fires at ~2/s naturally, so a 120ms floor never touches it.
	"shot_special": 120,
}

var _streams: Dictionary = {}              # id (String) -> AudioStream
var _pool: Array[AudioStreamPlayer] = []
var _pool_next := 0
var _music_player: AudioStreamPlayer
var _last_play_ms: Dictionary = {}          # id (String) -> Time.get_ticks_msec() of its last play()
var _sfx_bus_idx := -1
var _music_bus_idx := -1
var _current_music := ""                    # id currently loaded on _music_player ("" = none)

func _ready() -> void:
	_ensure_buses()
	_load_streams()
	_build_pool()
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = MUSIC_BUS
	add_child(_music_player)
	# Apply the saved mute preference immediately so boot never has a stray audible frame.
	AudioServer.set_bus_mute(_sfx_bus_idx, not SaveManager.sfx_on())
	AudioServer.set_bus_mute(_music_bus_idx, not SaveManager.music_on())

## Creates the SFX/Music buses if they don't already exist (re-running _ready via a
## hotload wouldn't duplicate them). Caches both indices for every later AudioServer call.
func _ensure_buses() -> void:
	_sfx_bus_idx = AudioServer.get_bus_index(SFX_BUS)
	if _sfx_bus_idx == -1:
		_sfx_bus_idx = AudioServer.bus_count
		AudioServer.add_bus(_sfx_bus_idx)
		AudioServer.set_bus_name(_sfx_bus_idx, SFX_BUS)
	_music_bus_idx = AudioServer.get_bus_index(MUSIC_BUS)
	if _music_bus_idx == -1:
		_music_bus_idx = AudioServer.bus_count
		AudioServer.add_bus(_music_bus_idx)
		AudioServer.set_bus_name(_music_bus_idx, MUSIC_BUS)

func _load_streams() -> void:
	for id in SFX_IDS:
		var path := "res://audio/sfx/%s.wav" % id
		if ResourceLoader.exists(path):
			_streams[id] = load(path)
	for id in MUSIC_IDS:
		var path := "res://audio/music/%s.wav" % id
		if ResourceLoader.exists(path):
			_streams[id] = load(path)

func _build_pool() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = SFX_BUS
		add_child(p)
		_pool.append(p)

## Plays a one-shot by id from the round-robin pool with a small random pitch jitter
## (default +/-8%). No-op if the id has no loaded stream (e.g. a typo) or it's still
## inside its MIN_INTERVAL_MS throttle window. Silence while muted is handled by the
## SFX bus itself (see set_sfx_on) — this never needs to check the mute state.
func play(id: String, pitch_jitter: float = 0.08) -> void:
	if not _streams.has(id):
		return
	var now := Time.get_ticks_msec()
	var min_gap: int = int(MIN_INTERVAL_MS.get(id, 0))
	if min_gap > 0 and now - int(_last_play_ms.get(id, -min_gap - 1)) < min_gap:
		return
	_last_play_ms[id] = now
	var p := _pool[_pool_next]
	_pool_next = (_pool_next + 1) % _pool.size()
	p.stream = _streams[id]
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()

## Starts looping music by id on the dedicated music player. A no-op if that id is
## already the current track (so re-entering the same scene doesn't restart it). Sets
## loop_mode/loop_end on the AudioStreamWAV directly — reliable headlessly and without
## an editor re-import, unlike relying on the WAV's .import loop settings. loop_end is
## in FRAMES, derived from length x mix_rate — format-agnostic, because the project's
## .wav imports are QOA-compressed (compress/mode=2) and `data` holds the compressed
## payload (~5x smaller than PCM), so any bytes-based frame math would land the loop
## point a fifth of the way into the track.
func music(id: String) -> void:
	if not _streams.has(id) or _current_music == id:
		return
	_current_music = id
	var stream: AudioStream = _streams[id]
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	_music_player.stream = stream
	_music_player.play()

## Toggles the SFX bus mute + persists the preference. Callers (PauseMenu/MainMenu
## toggle buttons) still call SaveManager.save_game() indirectly via this — the
## preference is saved immediately so it survives a crash/kill, not just a clean exit.
func set_sfx_on(on: bool) -> void:
	AudioServer.set_bus_mute(_sfx_bus_idx, not on)
	SaveManager.set_sfx_on(on)
	SaveManager.save_game()

func set_music_on(on: bool) -> void:
	AudioServer.set_bus_mute(_music_bus_idx, not on)
	SaveManager.set_music_on(on)
	SaveManager.save_game()

func sfx_on() -> bool:
	return not AudioServer.is_bus_mute(_sfx_bus_idx)

func music_on() -> bool:
	return not AudioServer.is_bus_mute(_music_bus_idx)
