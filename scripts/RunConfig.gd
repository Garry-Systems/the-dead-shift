extends Node
## AUTOLOAD (registered in project.godot as "RunConfig"). Holds the run-setup choices
## the menu makes — character + game mode — and carries them into the gameplay scene.
## Session-only (no persistence). No class_name: the autoload name is already global.

var character_id := "ryan"
var mode := "endless"        # "endless" | "boss_rush"
