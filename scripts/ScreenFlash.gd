class_name ScreenFlash
extends CanvasLayer
## A brief full-screen white flash that fades out and frees itself. Used for Ryan Ace's
## projectile-purge ability. Self-contained: spawn it into the scene and forget it.
## PROCESS_MODE_ALWAYS so a purge that pauses the tree (e.g. a level-up landing the same
## frame) still finishes its fade instead of parking a white wash over the paused overlay.

const PEAK_ALPHA := 0.7   # how bright the flash starts
const FADE_TIME := 0.25   # seconds to fade to transparent, then free

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30   # above the HUD — a true screen-wide flash
	var rect := ColorRect.new()
	rect.color = Color(1.0, 1.0, 1.0, PEAK_ALPHA)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	var tw := create_tween()
	tw.tween_property(rect, "color:a", 0.0, FADE_TIME)
	tw.tween_callback(queue_free)
