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
const SHOOT_ONLY_WHILE_STILL := true  # gun only fires while the player is standing still (raises difficulty)
const GUN_FIRE_INTERVAL := 0.20       # seconds between shots
const GUN_RANGE := 600.0              # px; bullet max travel distance
const BULLET_SPEED := 800.0           # px/sec
const BULLET_DAMAGE := 25.0
const BULLET_LIFETIME := 1.5          # seconds before a bullet despawns

# --- Weapon upgrade cards (Phase 3 step 2; distinct from loot "talents") ---
const UPGRADE_DAMAGE_PCT := 0.20       # "Hollow Points" damage card
const UPGRADE_FIRE_RATE_PCT := 0.15    # "Hair Trigger" fire-rate card
const UPGRADE_BULLET_SPEED_PCT := 0.15 # "Overpressure" bullet-speed card
const UPGRADE_RANGE_PCT := 0.15        # "Long Barrel" range card
const UPGRADE_CHOKE_PCT := 0.30        # "Tighter Choke" spread reduction
const UPGRADE_BURN_DPS := 8.0          # incendiary damage per second
const UPGRADE_BURN_DURATION := 3.0     # incendiary burn duration (seconds)
const FLAME_BURN_DPS := 10.0           # Flamethrower base burn (always ignites)
const FLAME_BURN_TIME := 1.5           # Flamethrower base burn duration, refreshed each tick

# --- Weapon talents (loot procs) ---
const TALENT_VULN_MAX := 1.0          # Marked: cap the bonus-damage-taken fraction (+100%)

# --- Enemy ---
const ENEMY_MOVE_SPEED := 70.0       # px/sec
const ENEMY_MAX_HEALTH := 50.0
const ENEMY_TOUCH_DAMAGE := 10.0     # damage per BITE on contact (discrete hit-and-bounce, not per-second)
const ENEMY_CONTACT_HIT_CD := 0.6    # seconds an enemy must wait between contact bites (can't multi-hit on one touch)
const ENEMY_BOUNCE_SPEED := 700.0    # px/sec shove away from the player on each bite (decays via Enemy.KNOCKBACK_DECAY)

# --- Spawner ---
const SPAWN_INTERVAL := 1.0           # seconds between spawns
const SPAWN_RADIUS := 1200.0          # distance from player to spawn at (tuned for the 1080x1920 portrait view's 960px half-height so enemies appear off-screen; was 700 for landscape — tune by feel)

# --- Difficulty / Waves (Phase 4 step 1) ---
const WAVE_DURATION := 30.0           # seconds per wave; wave = floor(run_time/this)+1
const SPAWN_INTERVAL_FLOOR := 0.25    # fastest the spawner ever gets (seconds)
const SPAWN_INTERVAL_DECAY := 0.92    # per-wave multiplier on SPAWN_INTERVAL (more enemies)
const ENEMY_HP_GROWTH := 1.12         # per-wave multiplier on enemy max health
const ENEMY_DMG_GROWTH := 1.05        # per-wave multiplier on enemy touch damage
const ENEMY_SPEED_GROWTH := 1.02      # per-wave multiplier on enemy move speed
const ENEMY_SPEED_CAP := 240.0        # px/sec; raised above the player's 220 so late enemies catch you

# After wave 10 enemies accelerate (Larry 2026-06-14): the gentle early growth freezes at
# ENEMY_LATE_WAVE and a steeper per-wave multiplier takes over, so HP keeps climbing and move
# speed eventually out-paces the player (PLAYER_MOVE_SPEED 220) — you must dash to escape.
const ENEMY_LATE_WAVE := 10            # wave after which the steeper ramp applies
const ENEMY_LATE_HP_GROWTH := 1.12     # per-wave HP multiplier past ENEMY_LATE_WAVE
const ENEMY_LATE_SPEED_GROWTH := 1.15  # per-wave speed multiplier past ENEMY_LATE_WAVE

# --- Boss (Phase 4 step 2) ---
const BOSS_WAVE_INTERVAL := 5         # a boss spawns every Nth wave (5, 10, 15, ...)
const BOSS_BASE_HP := 1500.0          # boss max health on wave 1 (scales with ENEMY_HP_GROWTH)
const BOSS_TOUCH_DAMAGE := 25.0       # boss contact damage/sec on wave 1 (scales w/ ENEMY_DMG_GROWTH)
const BOSS_MOVE_SPEED := 45.0         # px/sec; deliberately slow, does not scale
const BOSS_SPAWN_RATE_MULT := 0.5     # normal spawns run at this fraction of rate while a boss lives
const BOSS_LATE_HP_GROWTH := 1.12     # extra per-wave boss HP multiplier past ENEMY_LATE_WAVE (mirrors trash)
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
# Alstar Tuck: a shockwave on his dash + a fire-rate buff on high-rarity guns.
const CHAR_ALSTAR_PURPLE_FIRE_PCT := 0.30   # Alstar: +fire rate when the equipped gun is purple+
const CHAR_ALSTAR_PURPLE_MIN_RARITY := 5    # "purple or above" = Savage (rarity 5) and up
const CHAR_ALSTAR_SHOCK_RADIUS := 320.0     # px reach of his dash shockwave (push + damage + talents)
const CHAR_ALSTAR_SHOCK_DAMAGE := 50.0      # flat damage to every enemy caught in the blast
const CHAR_ALSTAR_SHOCK_FORCE := 1200.0     # px/sec knockback impulse away from him (decays via Enemy.KNOCKBACK_DECAY)
# Ryan Ace: his dash purges every enemy projectile + instant-reloads an equipped AK.
const CHAR_RYAN_PURGE_FX_RADIUS := 520.0    # px radius of the (cosmetic) purge pulse ring
const CHAR_RYAN_ABILITY_COOLDOWN := 15.0    # seconds between purges (the dash itself stays on DASH_COOLDOWN)

# --- Reload (Spec 2) ---
const RELOAD_TIME_FLOOR := 0.15             # seconds; minimum effective reload after speed bonuses
const UPGRADE_RELOAD_PCT := 0.20            # "Fast Hands" upgrade card: -% reload time
const UPGRADE_MAG_PCT := 0.50               # "Extended Mag" upgrade card: +% magazine size
const CHAR_JIMBO_SNIPER_RELOAD_PCT := 0.20  # Jimbo's sniper perk: -% reload time

# --- Coins / economy (Phase 6 Spec 1) ---
const COIN_BASE := 10          # flat coins for finishing any run
const COIN_PER_WAVE := 5       # coins per wave reached
const COIN_PER_BOSS := 25      # coins per boss defeated
const COIN_PER_KILL := 1       # coins per trash enemy killed

# --- Boss framework v1 ---
const BOSS_FIRST_CAST_DELAY := 1.0     # seconds before a boss's first pattern after spawn/phase-enter
const PATTERN_WINDUP_MIN := 0.5        # telegraph readability clamp (min seconds)
const PATTERN_WINDUP_MAX := 1.2        # telegraph readability clamp (max seconds)
const AIMED_BAND_THICKNESS := 26.0     # px half-width of an AimedBand's damaging segment
const AIMED_BAND_ACTIVE := 0.15        # seconds an AimedBand stays damaging after the telegraph
const AIMED_BAND_DAMAGE := 30.0        # default AimedBand hit damage
const AIMED_BAND_LENGTH := 1100.0      # px default beam length (crosses the 1080x1920 portrait view)
const BOSS_PROJECTILE_SPEED := 200.0   # px/sec for ProjectileEmitter hazards
const BOSS_PROJECTILE_DAMAGE := 12.0   # flat damage a boss projectile deals on hit
const BOSS_PROJECTILE_LIFETIME := 3.0  # seconds before a boss projectile despawns
const ZONE_DEFAULT_RADIUS := 90.0      # px default ZoneFill radius
const ZONE_DEFAULT_DPS := 18.0         # ZoneFill damage/sec while the player stands in it
const ZONE_DEFAULT_DURATION := 4.0     # seconds a ZoneFill puddle persists
const DEBUFF_JAM_DURATION := 2.0       # default gun-jam length (seconds)
const DEBUFF_SLOW_FACTOR := 0.5        # default move-speed cut (0.5 = half speed)
const DEBUFF_SLOW_DURATION := 2.5      # default slow length (seconds)

# Brood Mother
const BROOD_HP := 2200.0               # wave-1 HP (scales with wave like the brute)
const BROOD_SUMMON_COUNT := 3          # adds spawned per summon cast
const BROOD_ZONE_DPS := 18.0           # acid-nest damage/sec
const BROOD_RING_COUNT := 8            # projectiles in the radial spit

# Heat Tyrant
const HEAT_HP := 1900.0                # wave-1 HP
const HEAT_BAND_DAMAGE := 30.0         # solar-flare beam damage
const HEAT_JAM_DURATION := 2.0         # "Forced Vent" gun-jam length

# --- Ranged enemy (Spitter) --- (spawn cadence now lives in the Enemies registry: min_wave/weight)
const RANGED_PREFERRED_DIST := 450.0     # px standoff the spitter tries to hold
const RANGED_FIRE_INTERVAL := 1.8        # seconds between shots
const RANGED_FIRE_RANGE := 700.0         # px; only fires within this range
const RANGED_PROJECTILE_SPEED := 320.0   # px/sec
const RANGED_PROJECTILE_DAMAGE := 12.0   # flat damage per hit

# --- Enemy slate (variety) ---
const ENEMY_HARD_SPEED_CAP := 360.0   # absolute px/sec ceiling AFTER per-type speed mults (bounds the Runner)
# Exploder: detonates on contact or death instead of dealing touch DPS.
const EXPLODER_BLAST_RADIUS := 110.0  # px; player within this on detonate takes the hit
const EXPLODER_BLAST_DAMAGE := 35.0   # flat damage on detonation
# Hive: stationary spawner.
const HIVE_SPAWN_INTERVAL := 4.0      # seconds between brood spawns
const HIVE_SPAWN_COUNT := 2           # shamblers per spawn tick
const HIVE_MAX_BROOD := 8             # lifetime cap on shamblers one hive can birth

# --- Boss Rush mode (always-N bosses + trash) ---
const BOSS_RUSH_BASE_COUNT := 3        # concurrent bosses kept on the map from the start
const BOSS_RUSH_LEVELS_PER_BOSS := 5   # +1 concurrent boss every this many player levels
const BOSS_RUSH_REWARD_MULT := 0.35    # boss-rush XP-gem reward fraction (toned down — bosses die constantly)
const BOSS_RUSH_HEAL_FRAC := 0.2       # boss-rush heal per kill (vs a FULL heal in endless)
const BOSS_KILL_HEAL_FRAC := 0.33      # endless boss-kill heal fraction (was a FULL heal)
const BOSS_RUSH_RELIC_CHANCE := 0.3    # boss-rush chance to drop a relic per boss kill

# --- Environmental hazards: collision layers (the project's first) ---
const COVER_LAYER_BIT := 4              # solid cover (cars/rubble) physics layer (1-indexed)
const DESTRUCTIBLE_LAYER_BIT := 5       # non-solid props (barrels/drums/crates) physics layer
const COVER_MASK := 1 << 3              # bitmask for layer 4, for raycast line-of-sight queries

# --- Obstacles: placement & caps ---
const OBSTACLE_TARGET_COUNT := 12       # destructibles to keep near the player (ambient density)
const OBSTACLE_HARD_CAP := 24           # max destructibles alive at once
const MAX_HAZARD_ZONES := 10            # max lingering hazard pools at once
const OBSTACLE_SPAWN_INTERVAL := 0.4    # seconds between ambient top-up spawns
const OBSTACLE_SPAWN_MIN_R := 1000.0    # ambient spawn ring inner radius (just off-screen)
const OBSTACLE_SPAWN_MAX_R := 1300.0    # ambient spawn ring outer radius
const OBSTACLE_KEEP_RADIUS := 1400.0    # destructibles within this count toward the target density
const OBSTACLE_CULL_RADIUS := 1800.0    # free destructibles beyond this from the player
const OBSTACLE_CULL_INTERVAL := 1.0     # seconds between cull passes
const OBSTACLE_CLUSTER_SIZE := 4        # obstacles dropped at each new wave
const OBSTACLE_CLUSTER_RADIUS := 500.0  # spread of a wave-drop cluster around the player
const OBSTACLE_CLUSTER_MIN_R := 120.0   # inner radius of wave-drop cluster ring

# --- Obstacle HP (flat; no wave scaling) + crate loot ---
const BARREL_HP := 60.0
const DRUM_HP := 70.0
const TRANSFORMER_HP := 90.0
const COVER_CAR_HP := 400.0             # tanky but clearable
const RUBBLE_HP := -1.0                 # < 0 = indestructible
const CRATE_HP := 25.0
const CRATE_GEM_COUNT := 5
const CRATE_COIN_REWARD := 3            # coins added to the run tally when a crate is smashed

# --- Barrel burst (reuses Shockwave) + chain ---
const BARREL_BURST_DAMAGE := 60.0
const BARREL_BURST_RADIUS := 140.0
const BARREL_BURST_FORCE := 900.0
const BARREL_CHAIN_RADIUS := 160.0      # neighboring barrels within this get a chain fuse
const CHAIN_DELAY := 0.1                # seconds before a fused barrel detonates (a time-spread ripple)
const CHAIN_MAX_PER_TICK := 3           # max fused barrels that may detonate in one frame (excess slips to the next)

# --- Hazard zones (lingering pools) ---
const HAZARD_WINDUP := 0.12             # brief arm/telegraph for a destructible-spawned zone (bypasses the boss PATTERN_WINDUP clamp)
const HAZARD_TICK_INTERVAL := 0.2       # ~5 Hz both-sides damage tick (not per-frame)
const ENEMY_HAZARD_DMG_MULT := 1.0      # anti-herding lever (lower if herding dominates)
const PLAYER_HAZARD_DMG_MULT := 1.0     # keep area-denial genuinely risky to the player
const FIRE_DPS := 25.0
const FIRE_RADIUS := 110.0
const FIRE_DURATION := 4.0
const ACID_DPS := 18.0
const ACID_RADIUS := 120.0
const ACID_DURATION := 5.0
const ACID_SLOW_FACTOR := 0.45          # acid slows whatever stands in it
const ACID_SLOW_DURATION := 0.5         # refreshed each tick while inside
const ACID_DRIFT_SPEED := 20.0          # px/sec gentle cloud drift
const ELEC_DPS := 15.0
const ELEC_RADIUS := 130.0
const ELEC_DURATION := 3.0
const ELEC_STUN_DURATION := 0.4         # electric stuns enemies (reuses freeze); refreshed each tick
const ELEC_CHAIN_COUNT := 4             # enemies the field arcs to per tick (visual + in-radius)

# --- Enemy anti-wedge steering around cover ---
const ENEMY_COVER_STEER := 0.8          # tangential nudge strength when a chasing enemy hits cover
