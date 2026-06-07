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
const GUN_RANGE := 600.0              # px; ignore enemies farther than this
const BULLET_SPEED := 800.0           # px/sec
const BULLET_DAMAGE := 25.0
const BULLET_LIFETIME := 1.5          # seconds before a bullet despawns

# --- Weapon talents (Phase 3 step 2) ---
const TALENT_DAMAGE_PCT := 0.20       # "Hollow Points" damage card
const TALENT_FIRE_RATE_PCT := 0.15    # "Hair Trigger" fire-rate card
const TALENT_BULLET_SPEED_PCT := 0.15 # "Overpressure" bullet-speed card
const TALENT_RANGE_PCT := 0.15        # "Long Barrel" range card
const TALENT_CHOKE_PCT := 0.30        # "Tighter Choke" spread reduction
const TALENT_BURN_DPS := 8.0          # incendiary damage per second
const TALENT_BURN_DURATION := 3.0     # incendiary burn duration (seconds)

# --- Enemy ---
const ENEMY_MOVE_SPEED := 70.0       # px/sec
const ENEMY_MAX_HEALTH := 50.0
const ENEMY_TOUCH_DAMAGE := 10.0     # damage per second while touching the player

# --- Spawner ---
const SPAWN_INTERVAL := 1.0           # seconds between spawns
const SPAWN_RADIUS := 700.0           # distance from player to spawn at

# --- Difficulty / Waves (Phase 4 step 1) ---
const WAVE_DURATION := 30.0           # seconds per wave; wave = floor(run_time/this)+1
const SPAWN_INTERVAL_FLOOR := 0.20    # fastest the spawner ever gets (seconds)
const SPAWN_INTERVAL_DECAY := 0.92    # per-wave multiplier on SPAWN_INTERVAL (more enemies)
const ENEMY_HP_GROWTH := 1.12         # per-wave multiplier on enemy max health
const ENEMY_DMG_GROWTH := 1.05        # per-wave multiplier on enemy touch damage
const ENEMY_SPEED_GROWTH := 1.02      # per-wave multiplier on enemy move speed
const ENEMY_SPEED_CAP := 140.0        # px/sec; enemies never move faster than this

# --- Boss (Phase 4 step 2) ---
const BOSS_WAVE_INTERVAL := 5         # a boss spawns every Nth wave (5, 10, 15, ...)
const BOSS_BASE_HP := 1500.0          # boss max health on wave 1 (scales with ENEMY_HP_GROWTH)
const BOSS_TOUCH_DAMAGE := 25.0       # boss contact damage/sec on wave 1 (scales w/ ENEMY_DMG_GROWTH)
const BOSS_MOVE_SPEED := 45.0         # px/sec; deliberately slow, does not scale
const BOSS_SPAWN_RATE_MULT := 0.5     # normal spawns run at this fraction of rate while a boss lives
const BOSS_XP_REWARD := 30            # number of XP gems dropped on boss death

# --- Boss ground slam ---
const SLAM_INTERVAL := 4.0            # seconds between slams
const SLAM_WINDUP := 0.8              # telegraph time before the shockwave expands
const SLAM_RADIUS := 220.0            # max shockwave radius (px)
const SLAM_EXPAND_TIME := 0.5         # seconds for the ring to grow 0 -> SLAM_RADIUS
const SLAM_DAMAGE := 35.0             # damage if the player is caught by the ring (once per slam)

# --- Relics (Phase 4 step 3) ---
const MAX_RELIC_SLOTS := 4            # held relic capacity (designed to be raised later)
const RELIC_DAMAGE_PCT := 0.25        # glass_edge: +% gun damage
const RELIC_BULLET_SPEED_PCT := 0.30  # heavy_rounds: +% bullet speed
const RELIC_RANGE_PCT := 0.30         # long_scope: +% gun range
const RELIC_FIRE_RATE_PCT := 0.15     # hairpin: +% fire rate (reduces fire_interval)
const RELIC_REGEN := 1.5              # field_kit: +HP/sec
const RELIC_PICKUP_PCT := 0.40        # lodestone: +% pickup radius
const RELIC_MOVE_SPEED_PCT := 0.15    # featherweight: +% move speed
const RELIC_MAX_HEALTH := 40.0        # vital_surge: +max HP (and heals the same)

# --- XP / Leveling ---
const XP_BASE := 5                    # XP needed to reach level 1
const XP_PER_LEVEL := 3               # extra XP required for each later level
const XP_GEM_VALUE := 1               # XP granted per gem
const PICKUP_RADIUS := 80.0           # px; gems within this drift to the player
const GEM_DRIFT_SPEED := 300.0        # px/sec a gem moves toward the player
const GEM_COLLECT_DISTANCE := 16.0    # px; closer than this = collected

# --- Characters (Spec 1) ---
const CHAR_RYAN_HP_BONUS := 50.0         # Ryan starts at 100+50 = 150 HP
const CHAR_RYAN_AK_DMG_PCT := 0.25       # Ryan: +damage when wielding the AK-47
const CHAR_RYAN_AK_FIRE_PCT := 0.15      # Ryan: +fire rate when wielding the AK-47
const CHAR_JIMBO_SPEED_PCT := 0.50       # Jimbo: +move speed always
const CHAR_JIMBO_SNIPER_DMG_PCT := 0.25  # Jimbo: +damage when wielding a sniper
const CHAR_JIMBO_SNIPER_FIRE_PCT := 0.15 # Jimbo: +fire rate when wielding a sniper
const CHAR_BOB_MAGNET_PCT := 0.25        # Bob: +pickup radius always

# --- Reload (Spec 2) ---
const RELOAD_TIME_FLOOR := 0.15             # seconds; minimum effective reload after speed bonuses
const TALENT_RELOAD_PCT := 0.20             # "Fast Hands" gun talent: -% reload time
const TALENT_MAG_PCT := 0.50                # "Extended Mag" gun talent: +% magazine size
const CHAR_JIMBO_SNIPER_RELOAD_PCT := 0.20  # Jimbo's sniper perk: -% reload time
