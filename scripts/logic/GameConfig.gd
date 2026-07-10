class_name GameConfig
## Central tunable values for Phase 1. Keep ALL gameplay numbers here so the game
## can be balanced in one place. Later phases move these into data/resource files.

# --- Player ---
const PLAYER_MOVE_SPEED := 220.0      # px/sec
const PLAYER_MAX_HEALTH := 100.0
const PLAYER_HEALTH_REGEN := 0.0      # HP/sec at start (upgrades raise this)
const PLAYER_SHOVE_DECAY := 1200.0     # px/sec^2 linear decay of an external shove impulse (Karen's scream) — 600 px/s dies in 0.5s ≈ 150px total

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

# --- Characters (Pack E, v0.1.54): the Janitor + the Delivery Girl ---
# The Janitor: dash drops a mop-bucket slick (a hurts-nobody HazardZone, player_pools-capped)
# that slows enemies; passive flat coin-per-kill bonus.
const CHAR_JANITOR_SLICK_RADIUS := 90.0       # px reach of the dropped slick
const CHAR_JANITOR_SLICK_DURATION := 4.0      # seconds the puddle itself lingers before self-freeing
const CHAR_JANITOR_SLICK_SLOW := 0.5          # move-speed cut applied to any enemy standing in it
const CHAR_JANITOR_SLICK_SLOW_DUR := 2.0      # seconds the slow lasts per tick (refreshed at HAZARD_TICK_INTERVAL while inside)
const CHAR_JANITOR_COIN_PER_KILL := 1.0       # flat bonus coins added to every kill (RunStats.coins_per_kill)
# The Delivery Girl: dash drops an ARMED Parting-Gift-style mine (shares Mine's own
# GameConfig.MAX_PLAYER_MINES cap/group automatically via Mine.spawn); passive +pickup radius.
# Magnitudes sit inside Parting Gift's own talent roll ranges (dmg 30-60, radius 90-150) —
# named CHAR_DELIVERY_* (NOT CHAR_COURIER_*: that prefix is already the Courier BOSS's, see
# GameConfig.COURIER_HP etc.) to stay collision-free with Bosses.gd/Courier.gd.
const CHAR_DELIVERY_MINE_DMG := 45.0
const CHAR_DELIVERY_MINE_RADIUS := 110.0
const CHAR_DELIVERY_PICKUP_PCT := 0.20        # Delivery Girl: +pickup radius always

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

# --- THE KAREN (boss #8, v0.1.60) ---
const KAREN_HP := 1600.0               # above Courier (1400), well under Manager (3000) — kit is the pressure, not the tank
const KAREN_SPEED_MULT := 0.85         # persistent chase-speed multiplier — quick for a boss
const KAREN_REVIEW_SLOW_FACTOR := 0.55 # "LEAVING A REVIEW" move-speed factor on the player
const KAREN_REVIEW_SLOW_DURATION := 2.5  # seconds the review slow lasts
const KAREN_DECOY_COUNT := 3           # decoy adds per cast (auto-aim steal, BroodMother idiom)
const KAREN_MANAGER_HP_MULT := 6.0     # MANAGER ON DUTY summon hp_mult — STACKS with apply_elite's ELITE_HP_MULT 2.5 → effective ~15x a wave-current trash zombie
const KAREN_SCREAM_RADIUS := 240.0     # scream nova max radius (slightly wider than SLAM_RADIUS)
const KAREN_SCREAM_DAMAGE := 30.0      # damage if the leading band catches the player (once per scream)
const KAREN_SCREAM_SHOVE_SPEED := 600.0  # px/sec initial shove; with PLAYER_SHOVE_DECAY 1200 ≈ 150px knockback

# SHIFT CHANGE toast debounce: the Hud edge-detects "no boss -> boss" each frame, which in Boss
# Rush can flicker on a same-frame boss-death + refill depending on Spawner/Hud process order.
const SHIFT_TOAST_COOLDOWN := 8.0      # min seconds between SHIFT CHANGE toasts

# --- THE TANKER (boss #9, v0.1.60) ---
const TANKER_TRAIL_SPACING := 90.0       # px of dash travel between fuel pool drops
const TANKER_TRAIL_MAX := 14             # live fuel pools cap — drop-oldest (cap_player_pools idiom, own group)
const TANKER_POOL_DPS := 20.0            # fuel-fire pool dps (scaled by the boss's special_mult; HazardZone's ENEMY_/PLAYER_ mults apply on top)
const TANKER_POOL_RADIUS := 70.0         # px pool radius
const TANKER_POOL_DURATION := 4.0        # seconds a pool burns after igniting
const TANKER_IGNITE_DELAY := 0.9         # puddle→ignite windup: cross the wet fuel early or lose the lane
const TANKER_JACKKNIFE_RETELEGRAPH := 0.4  # pause between the two JACKKNIFE dashes (re-aims at the player)
const TANKER_HP := 2400.0              # second-tankiest after Manager (3000) — a truck
const TANKER_SPEED_MULT := 0.5         # crawls between bursts; the dashes ARE the mobility
const TANKER_CHARGE_SPEED := 600.0     # px/sec dash (under Courier's 650 but lasts longer)
const TANKER_CHARGE_DURATION := 1.0    # seconds per dash — a long haul so the trail matters
const TANKER_JACKKNIFE_SPACING := 60.0 # denser P3 trail (base spacing 90)
const TANKER_RUPTURE_RADIUS := 260.0   # P3 tank-rupture ExpandingRing radius
const TANKER_RUPTURE_DAMAGE := 40.0    # tank-rupture damage

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

# --- Talent Overhaul, Phase 2 (29 new talents / 16 new proc kinds) ---

# Night Terror (onhit_fear): Risk #10 hard cap so a feared ranged enemy can't drag off-screen.
const TALENT_FEAR_MAX_DURATION := 2.0        # seconds; Enemy.apply_fear() clamps to this

# Double Tap (oncrit_echo): the second hit lands a beat after the first (visual separation);
# its gold number is pushed with source_id 0 (proximity fallback) offset past the crit ICD's
# own dedupe radius so it renders as a SECOND number instead of being suppressed as "same enemy".
const TALENT_ECHO_DELAY := 0.06              # seconds before the echo hit resolves
const TALENT_ECHO_TEXT_OFFSET := 34.0        # px; must exceed COMBAT_TEXT_CRIT_DEDUPE_RADIUS (30)

# Septic Shock (onhit_dot_detonate): double-ring proc — outer green (full radius) + inner orange.
const TALENT_RUPTURE_INNER_FRAC := 0.5       # inner ring size, as a fraction of the outer radius

# Outbreak (onkill_spread): hard target cap on the corpse's status-spread (group scan like _explode).
const TALENT_OUTBREAK_SPREAD_CAP := 6

# Parting Gift (onkill_mine): pooled proximity mine, capped + auto-expiring like every other
# player-placed transient (mirrors MAX_PLAYER_POOLS / MAX_LEECH_MOTES' evict-oldest idiom).
const MAX_PLAYER_MINES := 6
const MINE_ARM_DELAY := 0.5                  # seconds before a dropped mine can detonate
const MINE_PROXIMITY_RADIUS := 40.0          # px; an enemy this close triggers detonation
const MINE_TTL := 10.0                       # seconds before an untriggered mine self-frees
const MINE_BLINK_HZ := 2.0                   # armed-tell blink rate
const MINE_RADIUS_PX := 8.0                  # visual disc radius

# Black Friday (onhit_gravity): capped, no-damage pull well — feeds AoE talents, never stacks.
const MAX_GRAVITY_WELLS := 1
const GRAVITY_WELL_PULL_SPEED := 140.0       # px/s knockback impulse toward the well's center per tick
                                              # (tick cadence reuses HAZARD_TICK_INTERVAL, Risks #11)

# Dead Man's Switch (onhurt_nova): retaliation blast on taking damage. Internal ICD is GUN-held
# (Gun._hurt_nova_cd), not global, since only one gun is ever equipped at a time.
const TALENT_HURT_NOVA_ICD := 6.0            # seconds between retaliation blasts
const TALENT_HURT_NOVA_FORCE := 250.0        # knockback force on the retaliation blast
const TALENT_HURT_NOVA_FLASH_ALPHA := 0.2    # dimmer than Ryan's purge (ScreenFlash.PEAK_ALPHA 0.7)

# Graveyard Shift (lowhp_frenzy): reuses the shared frenzy channel (Bloodrush/Adrenaline/Rampage
# are the other sources; max-wins across all four is deliberate, not a bug — Risks #9).
const TALENT_LOWHP_FRENZY_REFRESH := 0.2     # add_frenzy() refresh duration while armed
const TALENT_GRAVEYARD_RING_RADIUS := 40.0   # Shockwave.flash() radius on the arm transition

# Closing Time (aura_slow): tick cadence reuses HAZARD_TICK_INTERVAL (never per-frame).
const TALENT_AURA_SLOW_REFRESH_DUR := 0.4    # apply_slow() duration per tick (> tick interval, no gaps)

# --- Elites (Pack A: Run variety, v0.1.50) ---
# Spawn roll: endless only, gated in Spawner (Boss Rush must stay completely untouched).
const ELITE_MIN_WAVE := 6                # no elite roll before this wave
const ELITE_CHANCE_BASE := 0.05          # + ELITE_CHANCE_PER_WAVE * wave, capped at ELITE_CHANCE_CAP
const ELITE_CHANCE_PER_WAVE := 0.005
const ELITE_CHANCE_CAP := 0.15
const ELITE_HP_MULT := 2.5               # elite max_health multiplier (applied post-configure)
const ELITE_GEM_VALUE_MULT := 3.0        # XP gem value multiplier on an elite kill
const ELITE_COIN_BONUS := 5              # RunStats.add_coins() on an elite kill
const ELITE_ARMORED_DR := 0.30           # Armored: -% damage taken
const ELITE_VOLATILE_MULT := 1.2         # Volatile: exploder blast dmg/radius x this
const ELITE_VOLATILE_FUSE := 0.6         # Volatile: telegraph seconds before the death-blast lands
const ELITE_SPLITTER_CHILD_COUNT := 2    # Splitter: runners spawned on death
const ELITE_SPLITTER_CHILD_HP_FRAC := 0.5 # Splitter: children's HP, as a fraction of the elite's OWN (scaled) max_health
const ELITE_SPLITTER_CHILD_OFFSET := 24.0 # px the two children are spread apart on spawn
const ELITE_ALPHA_RADIUS := 300.0        # Alpha aura reach
const ELITE_ALPHA_SPEED_PCT := 0.20      # Alpha aura: +% move speed to enemies in range
const ELITE_ALPHA_DMG_PCT := 0.20        # Alpha aura: +% damage to enemies in range
const ELITE_ALPHA_BUFF_REFRESH := 0.4    # apply_elite_buff() duration per tick (> HAZARD_TICK_INTERVAL, no gaps — same idiom as TALENT_AURA_SLOW_REFRESH_DUR; when the Alpha dies, ticking stops and the buff decays on its own)

# --- Night-shift events (Pack A: Run variety, v0.1.50) ---
# Endless only, one active max; rolled at each new wave past NIGHT_EVENT_MIN_WAVE.
const NIGHT_EVENT_MIN_WAVE := 4
const NIGHT_EVENT_CHANCE := 0.22
const NIGHT_EVENT_DURATION := 30.0       # ~1 wave (mirrors WAVE_DURATION)
const BLOOD_MOON_SPAWN_MULT := 0.5       # spawn interval x this while active (faster spawns)
const BLOOD_MOON_COIN_PER_KILL := 1      # flat bonus coins per kill while the moon is up (a run-end mult delta only ever paid if the run ENDED mid-event)
const BLOOD_MOON_TINT_STRENGTH := 0.15   # CanvasModulate: how far toward red (~15%)
const FOG_BANK_DIM := 0.35               # CanvasModulate: how far toward black (~35% dim)
const FOG_BANK_GEM_MULT := 2.0           # XP gem value x this while active
const POWER_SURGE_CHAIN_BONUS := 2       # + chain jumps (gun lightning fire + TalentEngine chain/bolt procs) while active
const RUSH_HOUR_MIN_COUNT := 6
const RUSH_HOUR_MAX_COUNT := 10
const RUSH_HOUR_MIN_R := 250.0           # px along the corridor from the player (not right on top)
const RUSH_HOUR_MAX_R := 900.0
const RUSH_HOUR_WIDTH := 220.0           # px perpendicular jitter across the corridor

# --- Dawn extraction (Pack A: Run variety, v0.1.50) ---
# Endless only. Triggers at the existing dawn hook (ShiftClock.dawn_run_time()).
const FINAL_SURGE_SECONDS := 90.0        # forced spawn floor + doubled elite chance before the chopper arrives
const FINAL_SURGE_ELITE_MULT := 2.0
const EXTRACT_WINDOW := 20.0             # seconds the chopper waits at the LZ before leaving
const EXTRACT_PAY_MULT := 1.5            # win payout: final_payout() total x this
const EXTRACTION_LZ_POS := Vector2(0.0, 460.0)  # apron spot near the forecourt, clear of the store/pumps
const EXTRACTION_LZ_RADIUS := 130.0
const EXTRACTION_CHOPPER_DESCEND_TIME := 3.0    # seconds the chopper's visual takes to settle onto the LZ (cosmetic only)
const EXTRACTION_CHOPPER_ROTOR_HZ := 6.0

# --- Juice: crit-kill hit-stop (Pack D: Stats + juice, v0.1.51) ---
const JUICE_HITSTOP_ENABLED := true    # hard switch, independent of the save-level EFFECTS toggle
const JUICE_HITSTOP_SCALE := 0.05      # Engine.time_scale during the freeze
const JUICE_HITSTOP_DURATION := 0.05   # REAL seconds the freeze lasts (SceneTreeTimer ignores time_scale + pause)

# --- Weapon fusion (Pack B: v0.1.52) ---
const FUSION_XP_MULT := 2.0    # sacrifice's scrap-band midpoint (Rarity.scrap_midpoint) x this = weapon XP granted to the target

# --- Juice: trauma-based screen shake (Pack D: Stats + juice, v0.1.51) ---
const SHAKE_MAX_OFFSET := 18.0         # px cap on the camera's visible shake offset at full (1.0) trauma
const SHAKE_DECAY := 2.5               # trauma drained per second (1.0 -> 0 in ~0.4s)
const SHAKE_FREQ := 26.0               # noise oscillation rate (Hz-ish)
const SHAKE_TRAUMA_PLAYER_HURT := 0.14      # any damaging hit on the player
const SHAKE_TRAUMA_BOSS_SLAM := 0.55        # ExpandingRing (boss ground slam) connecting
const SHAKE_TRAUMA_BLAST_MIN := 0.22        # Shockwave.blast floor (small blasts, e.g. a barrel burst)
const SHAKE_TRAUMA_BLAST_MAX := 0.8         # Shockwave.blast ceiling (a big radius blast)
const SHAKE_TRAUMA_BLAST_REF_RADIUS := 320.0  # blast radius at which trauma reaches SHAKE_TRAUMA_BLAST_MAX
const SHAKE_TRAUMA_EXTRACTION := 0.85       # dawn-extraction chopper touchdown
const SHAKE_TRAUMA_DAWN := 0.6              # dawn clock-crossing banner

# --- Challenge board + Daily Shift (Pack C: v0.1.53) ---
const CHALLENGE_ACTIVE_COUNT := 3          # active challenge slots shown at once (also the daily rotation draw size)
const CHALLENGE_KILLS_TARGET := 60         # kill N zombies
const CHALLENGE_ELITE_KILLS_TARGET := 8    # kill N elite zombies
const CHALLENGE_BOSS_KILLS_TARGET := 3     # defeat N bosses
const CHALLENGE_CLOCK_HOUR := 2            # "reach 2:00 AM" — target read live via ShiftClock.run_time_for_hour()
const CHALLENGE_BLOOD_MOON_TARGET := 1     # survive N Blood Moons (event runs to completion, not interrupted by death)
const CHALLENGE_POWER_SURGE_KILLS_TARGET := 15   # kill N enemies while a Power Surge is active
const CHALLENGE_CRATES_TARGET := 3         # open N crates (menu action, bumped immediately — not a run-flush counter)
const CHALLENGE_FUSIONS_TARGET := 2        # fuse N weapons (menu action, bumped immediately)
const CHALLENGE_EXTRACTION_TARGET := 1     # win an extraction (Dawn Extraction chopper LZ)
const CHALLENGE_FIRE_KILLS_TARGET := 20    # kill N enemies while they're burning (incendiary DoT active at the kill)
const CHALLENGE_ELECTRIC_KILLS_TARGET := 20   # kill N enemies via TalentEngine._chain's lightning-arc damage
const CHALLENGE_POISON_KILLS_TARGET := 20  # kill N enemies while Venom's poison DoT is active at the kill

# --- Sprites (Pack F: v0.1.55) ---
const SPRITE_ENEMY_PX := 32.0   # native canvas size of art/enemies/<id>.png (matches the old shared enemy.png/ranged_enemy.png, so trash-type Sprite2D scales need no change on swap)
const SPRITE_BOSS_PX := 48.0    # native canvas size of art/bosses/<id>.png — bigger canvas than the old shared enemy.png, so BossBase scales its Sprite2D by SPRITE_ENEMY_PX/SPRITE_BOSS_PX on swap to keep the same on-screen size

# --- Employee Rank + unlockable modes (Pack G: v0.1.58) ---
# Rank is DERIVED from lifetime rank_xp (see Ranks.gd) — nothing but the XP itself is ever saved.
const RANK_COUNT := 10
const RANK_NAMES: Array[String] = [
	"TRAINEE", "CLERK", "NIGHT CLERK", "SHIFT LEAD", "KEYHOLDER",
	"ASSISTANT MANAGER", "STORE MANAGER", "DISTRICT MANAGER", "REGIONAL DIRECTOR", "FRANCHISE OWNER",
]
# Starter values: ~500-900 coins/run -> rank 3 (NIGHT CLERK) in ~2-3 runs, rank 7 (STORE MANAGER)
# ~30 runs, rank 10 (FRANCHISE OWNER) the long chase. Index i's threshold unlocks rank i+1.
const RANK_THRESHOLDS: Array[int] = [0, 500, 1500, 3500, 7000, 12000, 20000, 32000, 50000, 75000]
const RANK_HORDE_UNLOCK := 3       # NIGHT CLERK
const RANK_OVERTIME_UNLOCK := 5    # KEYHOLDER
const RANK_HARDCORE_UNLOCK := 7    # STORE MANAGER

const HORDE_SPAWN_MULT := 0.5      # HORDE NIGHT: spawn interval x this (reuses the Blood-Moon spawn-interval-mult mechanism)

const HARDCORE_COIN_MULT := 3.0       # HARDCORE: RunStats.coin_mult x this at run start (composes with the "Silver Tongue" card — same accumulator)
const HARDCORE_WEAPON_XP_MULT := 2    # HARDCORE: weapon XP x this at the end-of-run flush (the one Inventory.add_run_xp chokepoint)

const OVERTIME_START_SECONDS := 240.0 # OVERTIME: DifficultyManager.run_time preset at run start (2:00 AM, ~wave 9)
# Enough raw XP for ~8 level-ups at run start (xp_mult is always 1.0 there — no Fast Learner card
# taken yet): sum of XpCurve.xp_for_level(0..7) = (5+0*3)+(5+1*3)+...+(5+7*3) = 124.
const OVERTIME_HEADSTART_XP := 124

# --- Commendations wall (Pack H: v0.1.59) ---
# 18 one-time lifetime badges (scripts/logic/Commendations.gd) — every target lives here per
# house rules (mirrors CHALLENGE_*_TARGET above). Starter values per the spec's own framing.
# The badge COUNT itself is deliberately NOT a const: Commendations.all().size() is the single
# source of truth for every "N/18" readout (a separate const could silently drift from the table).
const COMMENDATION_FIRST_DAY_TARGET := 1
const COMMENDATION_PUNCHING_IN_TARGET := 10
const COMMENDATION_CAREER_CLERK_TARGET := 100
const COMMENDATION_EXTERMINATOR_TARGET := 2500
const COMMENDATION_GENOCIDE_SHIFT_TARGET := 25000
const COMMENDATION_PEST_CONTROL_TARGET := 100
const COMMENDATION_MIDDLE_MANAGEMENT_TARGET := 25
const COMMENDATION_UPPER_MANAGEMENT_TARGET := 100
const COMMENDATION_DAWN_PATROL_TARGET := 1
const COMMENDATION_WEEK_ONE_TARGET := 5
const COMMENDATION_EMPLOYEE_OF_MONTH_TARGET := 7
const COMMENDATION_REGULAR_TARGET := 10
const COMMENDATION_GOLDEN_TICKET_TARGET := 1
const COMMENDATION_OVER_THE_RAINBOW_TARGET := 1
const COMMENDATION_BIG_SPENDER_TARGET := 50
const COMMENDATION_RECYCLER_TARGET := 10
const COMMENDATION_TASKMASTER_TARGET := 25
const COMMENDATION_PAYDAY_TARGET := 2000

# Reward tiers, scaled scrap -> titan by difficulty (rank_xp_grant 100/250/500 + a one-time crate).
const COMMENDATION_TIER_EASY_XP := 100
const COMMENDATION_TIER_MED_XP := 250
const COMMENDATION_TIER_HARD_XP := 500
const COMMENDATION_TIER_EASY_CRATE := "scrap_crate"
const COMMENDATION_TIER_MED_CRATE := "munitions_cache"
const COMMENDATION_TIER_HARD_CRATE := "titan_crate"
