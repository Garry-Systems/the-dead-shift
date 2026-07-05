extends Node
## AUTOLOAD (registered in project.godot as "RunConfig"). Holds the run-setup choices
## the menu makes — character + game mode — and carries them into the gameplay scene.
## Session-only (no persistence). No class_name: the autoload name is already global.

var character_id := "ryan"
var mode := "endless"        # "endless" | "boss_rush"

## Set by GameOver's STORE button just before returning to the menu; MainMenu._ready()
## consumes (and resets) this to land directly in the store view instead of the hub.
var open_store_on_menu := false
