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
	"boss_roar", "dawn_sting", "car_alarm", "relic_choice", "cursed_reveal", "basement_descend",
	"truck_jingle", "truck_honk", "driveby_siren",
	"ability_ready", "ability_turret", "ability_deadeye", "ability_ghost", "ability_jackpot",
	"ability_airdrop",
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
	# Final-review fix: without this, the pool/music players pause with the rest of the tree,
	# so SFX fired while paused go silent — LevelUpUI's reroll button (_on_reroll_pressed's
	# "ui_tap", scripts/LevelUpUI.gd) and GameOver.trigger_win's "dawn_sting" (scripts/GameOver.gd,
	# called with get_tree().paused already true) both need to be heard while paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	_load_streams()
	_build_pool()
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = MUSIC_BUS
	add_child(_music_player)
	# Apply the saved volume immediately so boot never has a stray audible frame.
	_migrate_legacy_mutes()
	_apply_bus_volume(_sfx_bus_idx, SaveManager.sfx_vol())
	_apply_bus_volume(_music_bus_idx, SaveManager.music_vol())

## Volume sliders (v0.1.72): saves from before the sliders only had ON/OFF booleans. A save
## that had SFX/MUSIC toggled OFF keeps its silence as volume 0.0 exactly once here — from
## then on set_*_volume below keeps the boolean in sync (on == vol > 0), so this never
## re-fires (an OFF bool can only coexist with a >0 vol on a pre-slider save).
func _migrate_legacy_mutes() -> void:
	if not SaveManager.sfx_on() and SaveManager.sfx_vol() > 0.0:
		SaveManager.set_sfx_vol(0.0)
	if not SaveManager.music_on() and SaveManager.music_vol() > 0.0:
		SaveManager.set_music_vol(0.0)

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
## SFX bus itself (see set_sfx_volume) — this never needs to check the mute state.
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

## Sets the SFX bus volume (0..1) + persists it. Called live from the PauseMenu/MainMenu
## volume sliders — the preference is saved immediately so it survives a crash/kill, not
## just a clean exit. Keeps the legacy sfx_on boolean in sync (see _migrate_legacy_mutes).
func set_sfx_volume(v: float) -> void:
	v = clampf(v, 0.0, 1.0)
	_apply_bus_volume(_sfx_bus_idx, v)
	SaveManager.set_sfx_vol(v)
	SaveManager.set_sfx_on(v > 0.001)
	SaveManager.save_game()

func set_music_volume(v: float) -> void:
	v = clampf(v, 0.0, 1.0)
	_apply_bus_volume(_music_bus_idx, v)
	SaveManager.set_music_vol(v)
	SaveManager.set_music_on(v > 0.001)
	SaveManager.save_game()

## Linear 0..1 -> bus dB, with a hard mute at (effectively) zero so "slider all the way
## down" is true silence, not linear_to_db's -60dB whisper.
func _apply_bus_volume(idx: int, v: float) -> void:
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.001)))
