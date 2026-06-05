class_name GameConfig
## Central tunable values for Phase 1. Keep ALL gameplay numbers here so the game
## can be balanced in one place. Later phases move these into data/resource files.

# --- Player ---
const PLAYER_MOVE_SPEED := 220.0      # px/sec
const PLAYER_MAX_HEALTH := 100.0
const PLAYER_HEALTH_REGEN := 0.0      # HP/sec at start (upgrades raise this)

# --- Dash ---
const DASH_SPEED := 700.0             # px/sec while dashing
const DASH_DURATION := 0.15           # seconds of dash movement
const DASH_COOLDOWN := 1.5            # seconds before next dash
const DASH_DOUBLE_TAP_WINDOW := 0.30  # max seconds between the two taps

# --- Gun ---
const GUN_FIRE_INTERVAL := 0.20       # seconds between shots
const GUN_RANGE := 600.0              # px; ignore zombies farther than this
const BULLET_SPEED := 800.0           # px/sec
const BULLET_DAMAGE := 25.0
const BULLET_LIFETIME := 1.5          # seconds before a bullet despawns

# --- Zombie ---
const ZOMBIE_MOVE_SPEED := 70.0       # px/sec
const ZOMBIE_MAX_HEALTH := 50.0
const ZOMBIE_TOUCH_DAMAGE := 10.0     # damage per second while touching the player

# --- Spawner ---
const SPAWN_INTERVAL := 1.0           # seconds between spawns
const SPAWN_RADIUS := 700.0           # distance from player to spawn at

# --- XP / Leveling ---
const XP_BASE := 5                    # XP needed to reach level 1
const XP_PER_LEVEL := 3               # extra XP required for each later level
const XP_GEM_VALUE := 1               # XP granted per gem
const PICKUP_RADIUS := 80.0           # px; gems within this drift to the player
const GEM_DRIFT_SPEED := 300.0        # px/sec a gem moves toward the player
const GEM_COLLECT_DISTANCE := 16.0    # px; closer than this = collected
