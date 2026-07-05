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
const FLAME_BURN_DPS := 30.0           # Flamethrower base burn — a real damage channel, not a tick
const FLAME_BURN_TIME := 3.0           # Flamethrower burn duration, refreshed each tick — melts after the sweep

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
const XP_GEM_VALUE_MAX := 15          # cap on hp-scaled gem value (elite/late kills pay more)
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
const QUIT_PAYOUT_FRAC := 0.75  # quit/restart from pause pays this fraction of the death payout

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
const BOSS_RUSH_HEAL_FRAC := 0.2       # boss-rush heal per kill (endless uses BOSS_KILL_HEAL_FRAC)
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
const MAX_PLAYER_POOLS := 8             # max player-placed pools (Acid Cannon, hurts_player:false) at once; oldest is evicted
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

# --- Forecourt (Pack 5): the gas-station spawn structure ---
const FUEL_PUMP_SIZE := 22.0                  # px rect half-extent (a bit chunkier than a barrel's 18)
const FUEL_PUMP_HP := 90.0                    # ~1.5x BARREL_HP (60)
const FUEL_PUMP_BURST_DAMAGE := 90.0          # ~1.5x BARREL_BURST_DAMAGE (60)
const FUEL_PUMP_BURST_RADIUS := 210.0         # ~1.5x BARREL_BURST_RADIUS (140)
const FUEL_PUMP_BURST_FORCE := 1350.0         # ~1.5x BARREL_BURST_FORCE (900)
const FUEL_PUMP_HAZARD_SCALE := 1.5           # scales the lingering fire pool's dps + radius vs a plain barrel

const FORECOURT_STORE_HALF_SIZE := Vector2(170.0, 150.0)  # store cover-body half-extent (px)
const FORECOURT_STORE_POS := Vector2(-260.0, -150.0)      # store center, offset from Forecourt origin (world 0,0)
const FORECOURT_STORE_BAND_HEIGHT := 36.0                 # "OPEN 24H" band strip height on the front (south) wall
const FORECOURT_STORE_DOOR_WIDTH := 64.0                  # visual-only door notch width on the front wall
const FORECOURT_PUMP_Y := -60.0                           # fuel pump row Y offset
const FORECOURT_PUMP_START_X := 20.0                      # first pump X offset
const FORECOURT_PUMP_SPACING := 110.0                     # gap between pump centers
const FORECOURT_PUMP_COUNT := 3                           # pumps in the row
const FORECOURT_SIGN_POS := Vector2(380.0, -230.0)        # GAS sign panel center offset
const FORECOURT_SIGN_PANEL_SIZE := Vector2(150.0, 50.0)   # sign panel width/height
const FORECOURT_SIGN_POLE_WIDTH := 10.0                   # sign pole thickness
const FORECOURT_KEEPOUT_RADIUS := 700.0                   # ObstacleField scatter/cull keep-out around the forecourt
const FORECOURT_SPAWN_KEEPOUT := 560.0                    # enemy/boss spawn keep-out from origin — covers the store+pumps footprint (farthest fixture corner ~525px from origin)
const FORECOURT_PLAYER_SPAWN := Vector2(0.0, 220.0)       # apron spawn point, clear of the building + pump row

# --- First-run onboarding hints (Pack 1) ---
const HINT_MOVE_SECONDS := 1.0   # cumulative seconds of player movement before hint 1 ("move") clears
const HINT_FIRE_SECONDS := 3.0   # cumulative seconds the gun is actively trying to fire before hint 2 ("shoot") clears (or first kill, whichever first)

# --- Level-up cards, Pack 2 (armor/dodge/crit/thorns/second wind/economy) ---
const UPGRADE_ARMOR_PCT := 0.15        # "Iron Skin" card: -% contact/bite damage taken (multiplicative, stacks)
const UPGRADE_DODGE_PCT := 0.08        # "Quick Step" card: +% chance to ignore any hit outright
const DODGE_CAP := 0.40                # hard ceiling on total dodge chance across all stacks
const UPGRADE_DASH_CD_PCT := 0.15      # dash-cooldown card: -% dash cooldown (multiplicative)
const UPGRADE_XP_PCT := 0.20           # "Fast Learner" card: +% XP gained per gem (multiplicative, stacks)
const UPGRADE_COIN_PCT := 0.20         # coin-gain card: +% end-of-run coin payout (death AND quit paths)
const UPGRADE_CRIT_CHANCE_PCT := 5.0   # "Kill Shot" card: + this many crit-chance points (0-100 scale, same units as TalentEngine's payload["crit_chance"])
const UPGRADE_CRIT_MULT_BONUS := 1.0   # "Kill Shot" card: + this much crit-multiplier bonus (1.0 = "double" damage on proc)
const UPGRADE_THORNS_MULT := 2.0       # thorns card: reflected damage = this x the biter's own raw bite damage
const SECOND_WIND_HP_FRAC := 0.50      # Second Wind: revive fraction of max HP on what would otherwise be a lethal hit

# --- Night-shift clock (Pack 3, endless only) ---
const SHIFT_START_HOUR := 22           # the clock reads 10:00 PM at run start
const SHIFT_END_HOUR := 6              # "dawn" — clock keeps climbing past this; the run continues
const SHIFT_SECONDS_PER_MINUTE := 1.0  # real seconds per in-game clock minute
const DAWN_BONUS_COINS := 250          # end-of-shift bonus, granted once per run at dawn

# --- Daily login streak (Pack 4) ---
const DAILY_STREAK_TIER_UP := 3        # streak this high or more: daily crate weight shifts one price tier up
const DAILY_STREAK_FLOOR := 7          # streak this high or more: daily crate result floored at munitions_cache-or-better

# --- Charge (dash) pattern defaults (Pack 7) ---
const CHARGE_SPEED := 520.0            # px/sec default dash speed
const CHARGE_DURATION := 0.55          # seconds default dash length
const CHARGE_DAMAGE := 30.0            # flat contact damage if the dash connects (once per dash)
const CHARGE_HIT_RADIUS := 56.0        # px distance from the dashing boss counted as a hit

# --- Night-shift staff bosses (Pack 7) ---
# The Manager: tanky/slow. Calls in staff adds, jams the gun, ground-slams.
const MANAGER_HP := 3000.0             # ~2x base — the tank of the roster
const MANAGER_SPEED_MULT := 0.6        # persistent chase-speed multiplier (slow)
const MANAGER_SUMMON_COUNT := 3        # staff adds per summon cast
const MANAGER_JAM_DURATION := 2.2      # "Written Up" gun-jam length

# The Night Stocker: fast, squishy, charges the player and litters cover behind it.
const STOCKER_HP := 1100.0             # below base — glass cannon, dies fast if you land hits
const STOCKER_SPEED_MULT := 1.7        # persistent chase-speed multiplier (fast)
const STOCKER_CRATE_SIZE := 22.0       # px rect half-extent of a dropped crate obstacle
const STOCKER_CRATE_DROP_DIST := 70.0  # px behind the boss a dropped crate lands
const STOCKER_CRATE_MAX := 6           # live stocker crates at once — can pressure but never seal a ring around the player (oldest evicted at cap)

# The Fryer: medium pace, denies ground with fire pools + heat-lamp bands.
const FRYER_HP := 2000.0               # medium
const FRYER_ZONE_DPS := 20.0           # fry-oil pool damage/sec
const FRYER_BAND_DAMAGE := 26.0        # heat-lamp band damage

# The Courier: mobile arena-crosser. Charges, radial parcel bursts, a slow-you-down aura.
const COURIER_HP := 1400.0             # below base — relies on mobility, not tankiness
const COURIER_SPEED_MULT := 1.3        # persistent chase-speed multiplier (brisk)
const COURIER_CHARGE_SPEED := 650.0    # px/sec — crosses more of the arena than the Stocker's charge
const COURIER_CHARGE_DURATION := 0.9   # seconds
const COURIER_RING_COUNT := 10         # radial burst projectile count
const COURIER_SLOW_DURATION := 3.0     # slow-aura debuff length
const COURIER_SLOW_FACTOR := 0.4       # slow-aura move-speed cut

# SHIFT CHANGE toast debounce: the Hud edge-detects "no boss -> boss" each frame, which in Boss
# Rush can flicker on a same-frame boss-death + refill depending on Spawner/Hud process order.
const SHIFT_TOAST_COOLDOWN := 8.0      # min seconds between SHIFT CHANGE toasts

# --- Talent VFX overhaul, Phase 1 (make every existing proc visible) ---
# CombatText: one pooled Node2D (see scripts/ui/CombatText.gd) — gold crit numbers + headline
# callout words. Caps are LOAD-BEARING (Risks #1): a Label-per-proc tanks horde frames.
const COMBAT_TEXT_SLOTS := 16                # preallocated entry slots (never grows)
const COMBAT_TEXT_MAX_POPS_PER_FRAME := 4    # excess pushes this frame are silently dropped
const COMBAT_TEXT_POP_TIME := 0.1            # seconds of the pop-in scale (1.15 -> 1.0)
const COMBAT_TEXT_LIFE := 0.6                # total seconds an entry lives (rise + fade)
const COMBAT_TEXT_FADE_TIME := 0.25          # seconds of fade-out at the end of LIFE
const COMBAT_TEXT_RISE_PX := 28.0            # px an entry rises over its life
const COMBAT_TEXT_X_JITTER := 6.0            # max px of random horizontal drift
const COMBAT_TEXT_CRIT_SIZE := 18            # font size, crit gold numbers
const COMBAT_TEXT_CALLOUT_SIZE := 22         # font size, headline-proc words
const COMBAT_TEXT_CRIT_ICD := 0.15           # per-enemy min gap between crit numbers (keyed on the enemy's instance id — see CombatText._push_crit)
const COMBAT_TEXT_CRIT_DEDUPE_RADIUS := 30.0 # px; id-less (source_id 0) fallback proxy for "same enemy"
const COMBAT_TEXT_CALLOUT_DEDUPE := 0.5      # seconds: an identical live callout word refreshes instead of taking a new slot

# TalentEngine per-frame transient-VFX budget (Risks #2): gameplay procs always apply; only
# their rings/lightning/motes shed load once a frame's worth of horde-wide procs exceeds this.
const TALENT_VFX_MAX_PER_FRAME := 6

# Fixed-radius proc rings (the "true radius" procs — explode/reload-nova/freeze-shatter — read
# their radius from the talent's own rolled `radius` mod instead).
const TALENT_VULN_RING_RADIUS := 26.0        # gold pulse on a Marked-family apply
const TALENT_EXECUTE_RING_RADIUS := 28.0     # blood-red flash on an execute-family kill
const TALENT_SHATTER_CORE_FRAC := 0.4        # inner white-core ring size, as a fraction of the shatter radius

# Overpen (Rebar/Railbreaker): the bullet sprite's per-pierce power-up read.
const TALENT_OVERPEN_SCALE_STEP := 1.06      # sprite scale multiplier per pierce
const TALENT_OVERPEN_BRIGHTEN := 0.15        # Color.lightened() fraction per pierce

# LeechMote (lifesteal talents): capped concurrent pooled motes, mirrors MAX_PLAYER_POOLS/
# MAX_HAZARD_ZONES' evict-oldest idiom.
const MAX_LEECH_MOTES := 4
const LEECH_MOTE_LIFE := 0.25                # seconds to lerp enemy -> player
const LEECH_MOTE_RADIUS := 4.0               # px
