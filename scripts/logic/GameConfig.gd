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
const MAX_RELIC_SLOTS := 4            # held relic capacity (overstocked raises this to 6 while held)
const RELIC_DAMAGE_PCT := 0.25        # glass_edge: +% gun damage
const RELIC_BULLET_SPEED_PCT := 0.30  # heavy_rounds: +% bullet speed
const RELIC_RANGE_PCT := 0.30         # long_scope: +% gun range
const RELIC_FIRE_RATE_PCT := 0.15     # hairpin: +% fire rate (reduces fire_interval)
const RELIC_REGEN := 1.5              # field_kit: +HP/sec
const RELIC_PICKUP_PCT := 0.40        # lodestone: +% pickup radius
const RELIC_MOVE_SPEED_PCT := 0.15    # featherweight: +% move speed
const RELIC_MAX_HEALTH := 40.0        # vital_surge: +max HP (and heals the same)

# --- Relics Overhaul "Lost & Found" (v0.1.66) — RELIC CHOICE drop moment + 27-relic pool ---
# §1/§2: the pick-1-of-2 drop moment + slots/scrapping.
const RELIC_CURSED_CHANCE := 0.35     # card B: chance the second roll is a CURSED relic instead of A's standard/prototype mix (card A is NEVER cursed)
const RELIC_DRY_COINS := 150          # paid instead of a choice when the un-held pool can't offer even one card
const RELIC_SKIP_COINS := 100         # paid when the player taps SKIP on a RELIC CHOICE instead of taking either card — equal to RELIC_SCRAP_COINS (standard scrap value): kills the take-then-scrap arb; starter value
const RELIC_SCRAP_COINS := 100        # pause-menu SCRAP: coins paid for freeing a held STANDARD/PROTOTYPE relic's slot
const RELIC_CURSED_SCRAP_COINS := 25  # SCRAP payout for a held CURSED relic (cheaper — the power already got used)

# Two new STANDARD relics (run-scoped RunStats multipliers, not player/gun props).
const RELIC_TIP_JAR_PCT := 0.15       # tip_jar: +% RunStats.coin_mult
const RELIC_PUNCH_CARD_PCT := 0.20    # punch_card: +% RunStats.weapon_xp_mult

# PROTOTYPE (10) — run-rule relics; magnitudes read by RelicEffects.gd (owns the hooks).
const RELIC_STATIC_TRAIL_DPS := 20.0     # static_soles: damage/sec of the dash's electric trail
const RELIC_STATIC_TRAIL_DUR := 1.0      # static_soles: how long the trail lingers (seconds)
const RELIC_DOUBLE_FUSE_PCT := 0.5       # double_fuse: second detonation's power, as a fraction of the first
const RELIC_DOUBLE_FUSE_DELAY := 0.3     # double_fuse: delay before the second detonation (seconds)
const RELIC_MAGNET_STREAK := 5           # magnet_coil: kills within the window needed to trigger the gem pull
const RELIC_MAGNET_WINDOW := 3.0         # magnet_coil: streak window (seconds); a gap this long resets the counter
const RELIC_INTERCOM_FEAR := 1.5         # intercom: fear duration applied to nearby trash on elite death (seconds)
const RELIC_ACCELERANT_PCT := 0.25       # accelerant: +% damage taken by burning enemies from ALL sources
const RELIC_TIMECLOCK_HOLD := 10.0       # overtime_clock: seconds the shift clock is held on each boss kill
const RELIC_SPARE_GEMS := 1              # spare_parts: extra gems dropped by crates & shelves
const RELIC_SPARE_COIN_CHANCE := 0.10    # spare_parts: chance of an additional coin burst on the same drop
const RELIC_RUBBER_MOVE_PCT := 0.05      # rubber_soles: +% move speed (on top of full slow immunity)
const RELIC_ADRENAL_REFUND := 2.0        # adrenal_valve: dash cooldown refunded per hit taken (seconds)
const RELIC_CHAIN_PIERCE := 1            # chain_letter: +pierce on every gun

# CURSED (7) — devil's bargains; opt-in only, slot B.
const RELIC_STAPLER_DMG_PCT := 0.40      # managers_stapler: +% gun damage
const RELIC_STAPLER_HEAL_FACTOR := 0.5   # managers_stapler: multiplier applied to ALL incoming healing
const RELIC_DRINK_SPEED_PCT := 0.25      # expired_drink: +% move speed AND +% fire rate
const RELIC_DRINK_HP_LOSS := 30.0        # expired_drink: max HP lost on pickup
const RELIC_DRINK_HP_FLOOR := 40.0       # expired_drink: max HP can never be reduced below this by the loss above
const RELIC_CARD_COIN_MULT := 2.0        # company_card: coin-payout multiplier while held
const RELIC_CARD_STUB_CUT := 0.25        # company_card: fraction cut from the FINAL pay-stub total (post-mult) at run end
const RELIC_PACT_HEAL_PER_KILL := 1.0    # blood_pact: HP healed per kill (the only heal source left while held)
const RELIC_NAMETAG_ELITE_MULT := 1.5    # cursed_nametag: elite spawn-chance multiplier
const RELIC_NAMETAG_GEM_MULT := 2.0      # cursed_nametag: elite gem-drop multiplier
const RELIC_OVERSTOCK_SLOTS := 2         # overstocked: extra relic slots granted (4 -> 6)
const RELIC_OVERSTOCK_HP_LOSS := 20.0    # overstocked: max HP lost on pickup
const RELIC_VEST_HEAL_CAP := 0.5         # dead_mans_vest: incoming healing capped at this fraction of max HP while held

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
const BOSS_CAST_RANGE := 2400.0        # beyond this the boss holds its patterns — prevents surface bosses reaching into the basement
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

# --- EMPLOYEE BENEFITS (roadmap-4 Pack A, v0.1.62) ---
const BENEFIT_COSTS := [25, 60, 140, 320, 700]  # scrap cost for level 1..5 of every 5-cap track
const BENEFIT_REVIVE_COST := 900         # UNION REP single level (Deep Clean, v0.1.67: 1500 -> 900 — the marquee benefit lands mid-season instead of ~50 runs)
const BENEFIT_REVIVE_HEAL_FRAC := 0.5    # revive restores this fraction of max HP
const BENEFIT_REVIVE_INVULN := 2.0       # seconds of post-revive invulnerability
const BENEFIT_HP_PER_LVL := 4.0          # INSURANCE: flat max HP per level (spawn baseline)
const BENEFIT_SPEED_PER_LVL := 0.02      # COMFY SHOES: move-speed fraction per level
const BENEFIT_XP_PER_LVL := 0.03         # NIGHT SCHOOL: xp-gain fraction per level
const BENEFIT_CASH_PER_LVL := 50         # SIGNING BONUS: run-start coins per level
const SIGNING_BONUS_VEST_TIME := 120.0   # seconds of shift time before the signing bonus fully vests (anti instant-quit farm)
const BENEFIT_DASH_CD_PER_LVL := 0.04    # STRETCH BREAKS: dash-cooldown cut per level
const BENEFIT_COIN_PER_LVL := 0.02       # REGISTER SKIM: coin-gain fraction per level
const BENEFIT_SCRAP_PER_LVL := 0.10      # PACK RAT: extra scrap from deconstructs per level

const HORDE_SPAWN_MULT := 0.5      # HORDE NIGHT: spawn interval x this (reuses the Blood-Moon spawn-interval-mult mechanism)

const HARDCORE_COIN_MULT := 3.0       # HARDCORE: RunStats.coin_mult x this at run start (composes with the "Silver Tongue" card — same accumulator)
const HARDCORE_WEAPON_XP_MULT := 2    ## hardcore ×2 weapon XP — composed ONLY inside CoinReward.weapon_xp_payout (the single site both end-of-run paths call)

const OVERTIME_START_SECONDS := 240.0 # OVERTIME: DifficultyManager.run_time preset at run start (2:00 AM, ~wave 9)
# Enough raw XP for ~8 level-ups at run start. xp_mult IS guaranteed 1.0 there (fixed, final-review
# round): Main.gd grants this headstart BEFORE Characters.apply_base applies NIGHT SCHOOL's
# xp_mult bonus — previously it ran AFTER, so NIGHT SCHOOL inflated the headstart into a free extra
# level on every OVERTIME run. Sum of XpCurve.xp_for_level(0..7) = (5+0*3)+(5+1*3)+...+(5+7*3) = 124.
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

# --- THE BASEMENT (roadmap-4 Pack E, v0.1.63) ---
const BASEMENT_MIN_WAVE := 3            # first wave a cellar door can roll
const BASEMENT_DOOR_CHANCE := 0.25      # per wave-edge roll (via RunConfig.rand_float — Daily stays seeded)
const BASEMENT_DAWN_LOCKOUT := 140.0    # door+gauntlet must never eat the extraction window
const BASEMENT_MAX_PER_RUN := 2         # doors per run
const BASEMENT_DOOR_LIFETIME := 45.0    # seconds an unentered door lingers
const BASEMENT_DESCEND_HOLD := 1.2      # seconds standing in the ring to descend
const BASEMENT_DOOR_MIN_DIST := 500.0   # door placement ring around the player (px)
const BASEMENT_DOOR_MAX_DIST := 900.0
const BASEMENT_OFFSET := Vector2(24000, 24000)  # gauntlet arena world offset
const BASEMENT_RADIUS := 800.0          # walled ring radius
const BASEMENT_DURATION := 60.0         # gauntlet seconds (shift clock keeps ticking — stolen time)
const BASEMENT_SPAWN_INTERVAL := 0.55   # dense trash cadence inside
const BASEMENT_ELITES := 2              # guaranteed elites per gauntlet (+1 past wave 10)
const BASEMENT_CRATE_FLOOR_BASE := 2    # reward crate rarity floor = BASE + wave/WAVES, capped
const BASEMENT_CRATE_FLOOR_WAVES := 5
const BASEMENT_CRATE_FLOOR_MAX := 7     # apex floor (red) — never guarantees the animated tiers
const BASEMENT_PICKUP_WINDOW := 8.0     # seconds to grab the crate before auto-ascend
const BASEMENT_DOOR_RING := 90.0        # standing-distance radius that counts as "on the door"
const BASEMENT_WALL_SEG_RADIUS := 34.0  # one wall segment's collision radius — MUST match the "rubble" row's circle size in Obstacles.gd (the wall reuses that row verbatim); Basement._build_wall computes the ring's segment count from this so segment edges always overlap (no gaps)
const BASEMENT_RIM_INSET := 100.0       # gauntlet spawns land this far inside BASEMENT_RADIUS
const BASEMENT_ELITE_INTERVAL := 10.0   # seconds between each forced-elite gauntlet spawn
const BASEMENT_STRAGGLER_RADIUS := 2000.0  # ascend cleanup: enemies past this dist from the surface point are gauntlet stragglers, freed on sight

# --- Coworkers (roadmap-4 Pack C, v0.1.64) ---
const COWORKER_CRATE_PRICE := 800               # STAFF FILE store price (coins)
const COWORKER_TRAIT_MIN_RARITY := 4            # rarity floor for a coworker to roll a trait (Deep Clean, v0.1.67: 5 -> 4, Lethal/blue and up, ~15% of pulls — visibility, not flattening; the trait ladder itself is untouched)
const COWORKER_STAT_PER_RARITY := 0.18          # Coworkers.stat_mult() slope per rarity tier above 1
const COWORKER_CAT_RATE := 4.0                  # seconds between cat pounces (base, pre rate_mult)
const COWORKER_CAT_DAMAGE := 40.0               # cat pounce base damage
const COWORKER_CAT_RANGE := 500.0               # px cat pounce target-acquire range
const COWORKER_CAT_PIN := 0.45                  # seconds a cat pounce pins its target
const COWORKER_DRONE_RATE := 1.1                # seconds between drone shots (base)
const COWORKER_DRONE_DAMAGE := 9.0              # drone shot base damage
const COWORKER_DRONE_RANGE := 420.0             # px drone target-acquire range
const COWORKER_DRONE_ORBIT := 90.0              # px drone hover-orbit radius around the player
const COWORKER_MANNEQUIN_CD := 12.0             # seconds between mannequin decoy placements
const COWORKER_MANNEQUIN_HP := 150.0            # mannequin decoy base HP
const COWORKER_MANNEQUIN_TAUNT_RADIUS := 400.0  # px radius the decoy taunts enemies within
const COWORKER_MANNEQUIN_TAUNT_TIME := 4.0      # seconds each taunt tick lasts
const COWORKER_FOLLOW_DIST := 120.0             # px hover-follow offset from the player (cat/mannequin idle stance)
const COWORKER_FOLLOW_SPEED := 260.0            # px/sec the companion closes the gap to its hover-follow point
const COWORKER_CAT_LUNGE_TIME := 0.3            # seconds for each leg of the pounce (dash out AND the snap back)
const COWORKER_DRONE_ORBIT_SPEED := 1.4         # rad/sec the drone circles the player at COWORKER_DRONE_ORBIT
const COWORKER_LEASH_SNAP := 1500.0             # px: any teleport source (basement descend/ascend) beyond this snaps the companion straight to its hover point instead of walking back at COWORKER_FOLLOW_SPEED

# --- Coworker traits (roadmap-4 Pack C, Task 3, review-mandated): one magnitude const per
# trait (Coworkers.trait_desc()'s displayed percentages are derived from these, never a
# separate hardcoded number — see Companion.gd/CompanionBullet.gd, the only readers). ---
const COWORKER_TRAIT_SHARP := 0.25              # +% cat/drone damage
const COWORKER_TRAIT_WIRED := 0.20              # +% cat/drone attack rate
const COWORKER_TRAIT_WIDE := 0.25               # +% cat/drone acquire range & mannequin taunt radius
const COWORKER_TRAIT_STEADY := 0.30             # +% mannequin HP & taunt duration (mannequin only)
const COWORKER_TRAIT_CHILLING_SLOW := 0.25      # cat/drone hit rider: slow factor applied on hit
const COWORKER_TRAIT_CHILLING_DUR := 1.5        # cat/drone hit rider: seconds the chilling slow lasts
const COWORKER_TRAIT_PINNING_CHANCE := 0.15     # cat/drone hit rider: chance to also apply_pin (duration reuses COWORKER_CAT_PIN)
const COWORKER_TRAIT_MAGNETIC := 0.40           # +% player pickup radius, granted once at Companion spawn (Delivery Girl's own mechanism)
const COWORKER_TRAIT_STUDIOUS := 0.10           # +% player xp_mult, granted once at Companion spawn

# --- Locations (Transfer Stores, v0.1.65): Locations.gd rank-gate thresholds. Compared against
# Ranks.rank_for()'s 1-indexed value (Locations.unlocked(id, rank)). ---
const LOC_MART_RANK := 2       # rank required to select BIG MART
const LOC_GARAGE_RANK := 4     # rank required to select THE PARKING GARAGE

# --- BIG MART (Transfer Stores, Task 3): shelf row, chain_id collapse, formation mode, freezer
# patches, storefront set-piece. ---
const SHELF_HP := 120.0                   # shelf destructible HP
const SHELF_HALF_W := 26.0                # shelf rect half-width (px) — Destructible "size"
const SHELF_HALF_H := 12.0                # shelf rect half-height (px) — Destructible "size_y"
const SHELF_CHAIN_RADIUS := 140.0         # a dying chain_id-carrying shelf lights same-chain_id neighbors within this
const SHELF_GEMS := 1                     # gems dropped per shelf kill
const MART_FORMATION_LEN_MIN := 3         # min shelves in one formation run
const MART_FORMATION_LEN_MAX := 5         # max shelves in one formation run
const FREEZER_SLOW := 0.35                # freezer patch slow factor (enemies + player)
const FREEZER_SLOW_DUR := 1.0             # seconds a single freezer slow tick lasts
const FREEZER_RADIUS := 110.0             # freezer patch AoE radius (px)
const FREEZER_DURATION := 45.0            # seconds a freezer patch lingers
const FREEZER_CHANCE_PER_WAVE := 0.5      # chance a wave edge drops a freezer patch (mart only)
# Set-piece (mirrors Forecourt's own store+pumps footprint; all built at world origin, well within
# the existing FORECOURT_KEEPOUT_RADIUS/FORECOURT_SPAWN_KEEPOUT — those checks are unconditional,
# not forecourt-gated, so they already protect any location's origin set-piece for free).
const MART_SLAB_HALF_SIZE := Vector2(190.0, 130.0)  # storefront slab half-extent (px)
const MART_SLAB_POS := Vector2(0.0, -240.0)         # slab center, offset from MartFront origin (world 0,0)
const MART_LANE_X := 90.0                 # each checkout lane's X offset from center (left/right)
const MART_LANE_START_Y := -90.0          # first shelf's Y in a checkout lane
const MART_LANE_SHELF_COUNT := 3          # shelves per checkout lane

# --- THE PARKING GARAGE (Transfer Stores, Task 4): pillar lattice, car alarms (wail), booth. ---
const PILLAR_RADIUS := 40.0               # pillar row's circle radius (px)
const PILLAR_GRID := 480.0                # lattice grid cell size (px) — world-aligned, NOT player-relative, so the same world spot is always the same cell
const PILLAR_DENSITY := 0.55              # fraction of scanned lattice nodes that resolve "pillar present" (deterministic hash roll, no RNG)
const WAIL_TIME := 6.0                    # seconds a car alarm wails once triggered
const WAIL_TAUNT_RADIUS := 500.0          # radius (px) a wailing car taunts "enemies"-group members within, each tick
const WAIL_TAUNT_TICK := 0.5              # seconds between taunt re-ticks while wailing
const WAIL_TAUNT_DUR := 1.2               # Enemy.taunt() duration passed on each tick (always outlives the tick — no aggro gap, same idiom as MannequinDecoy's TICK_INTERVAL/taunt_time relationship)
const WAIL_MAX_CONCURRENT := 2            # global cap on simultaneously wailing cars ("wailing_cars" group). Drop-oldest SILENCES the wail (Destructible.silence_wail) — the car itself is never freed
const WAIL_SFX_MIN_GAP_MS := 1500         # min ms between "car_alarm" (see Destructible._play_wail_sfx) plays, shared across ALL wailing cars combined
# Set-piece (mirrors MartFront's slab/lane footprint; built at world origin, well within the
# existing FORECOURT_KEEPOUT_RADIUS/FORECOURT_SPAWN_KEEPOUT — those checks are unconditional, not
# location-gated, so they already protect any location's origin set-piece for free).
const GARAGE_BOOTH_HALF_SIZE := Vector2(80.0, 70.0)   # attendant booth half-extent (px)
const GARAGE_BOOTH_POS := Vector2(0.0, -240.0)        # booth center, offset from GarageBooth origin (world 0,0)
const GARAGE_ARM_HALF_SIZE := Vector2(70.0, 8.0)      # barrier arm half-extent (px) — size_y makes it a thin rect, not a square
const GARAGE_ARM_OFFSET_X := 150.0                    # each arm's X offset from center (left/right)
const GARAGE_ARM_Y := -150.0                          # both arms' Y position (between the booth and the spawn apron)
const GARAGE_ARM_HP := 40.0   ## breakable gate arm — walk-through props must never eat bullets forever

# --- THE MYSTERY SHOPPER (boss #10, Night Shift Stories v0.1.68): concealed-boss seam ---
# Starts disguised as ordinary horde filler (shared enemy.png, no boss bar/toast) and reveals
# on either trigger below, then re-cloaks at every phase edge (0.66 / 0.33 health fraction).
const SHOPPER_HP := 1800.0                  # between Karen (1600) and Fryer (2000)
const SHOPPER_REVEAL_DAMAGE := 60.0         # cumulative damage taken since the last cloak that forces a reveal
const SHOPPER_REVEAL_RANGE := 120.0         # px — player closing to this range also forces a reveal (strike range)
# Bosses share a fixed, non-wave-scaled chase base (BOSS_MOVE_SPEED 45 — see DifficultyCurve.
# boss_stats) unlike trash (which scales per-wave off ENEMY_MOVE_SPEED), so these two multipliers
# are a relative-parity choice, not literal parity with Enemies.gd's shambler/runner spd_mult:
const SHOPPER_CONCEALED_SPEED_MULT := 0.35  # concealed drift toward the player — reads as a slow shambler amble, not a chase
const SHOPPER_REVEALED_SPEED_MULT := 1.7    # revealed persistent chase pace — matches STOCKER_SPEED_MULT's "fast" anchor (closest existing runner-class boss)
const SHOPPER_CADENCE := 2.8                # seconds between revealed lunge casts (per spec)
const SHOPPER_CHARGE_SPEED := 480.0         # px/sec — a short slash lunge, well under Courier's 650 arena-crossing charge
const SHOPPER_CHARGE_DURATION := 0.35       # seconds — short, per spec ("fast slash combos", not a long dash)
const SHOPPER_REVEALED_SCALE := 2.4         # revealed Sprite2D scale (Courier's baked .tscn value); concealed stays at the shambler's baked 1.0 — the reveal visibly GROWS her to boss size

# --- THE MASCOT (boss #11, Night Shift Stories v0.1.68): shedding, accelerating duel ---
# Phase = costume layer. Each threshold (0.66 / 0.33) sheds: a RING burst, then the collider
# radius AND Sprite2D scale are set to MASCOT_SCALE_L* * the Courier-clone .tscn's baked base
# (radius 46 / scale 2.4) — NOT compounded onto the current value, so the ladder always reads
# off the same fixed base. Speed climbs via each phase's own speed_mult (BossBase's existing
# mechanism — no extra code needed). HP is front-loaded: L1's slow bulk carries most of the bar.
const MASCOT_HP := 2600.0                 # 2nd-tankiest costume boss — between Tanker (2400) and Manager (3000)
const MASCOT_SCALE_L1 := 1.15             # FULL SUIT — bulked up above the Courier-clone base
const MASCOT_SCALE_L2 := 0.9              # HALF SUIT — shrinking toward base
const MASCOT_SCALE_L3 := 0.7              # THE PERFORMER — tiny, runner-fast
const MASCOT_SPEED_MULT_L1 := 0.55        # slow, tanky presence
const MASCOT_SPEED_MULT_L2 := 0.9         # charges start landing
const MASCOT_SPEED_MULT_L3 := 1.35        # relentless — faster than the player's base walk
const MASCOT_CADENCE_L1 := 4.4            # seconds between casts — ground slam + summon
const MASCOT_CADENCE_L2 := 3.6            # charge + slam
const MASCOT_CADENCE_L3 := 2.0            # short erratic dashes — a duel
const MASCOT_SLAM_RADIUS := 220.0         # L1/L2 ground-slam (RING) radius — matches SLAM_RADIUS's default
const MASCOT_SLAM_DAMAGE := 30.0          # L1/L2 ground-slam damage
const MASCOT_SUMMON_COUNT := 2            # "2 fans" summoned by L1's SUMMON cast
const MASCOT_SHED_RING_RADIUS := 260.0    # the on_enter shed-burst RING (wider than the slam — the costume coming apart)
const MASCOT_SHED_RING_DAMAGE := 25.0     # shed-burst damage
const MASCOT_L3_CHARGE_SPEED := 550.0     # px/sec — L3's short erratic dash (faster than Shopper's 480 slash-lunge, under Courier's 650 arena-crosser)
const MASCOT_L3_CHARGE_DURATION := 0.3    # seconds — short, per spec

# --- VISITORS (Night Shift Stories v0.1.68): physical arrivals — a new event class, distinct
# from NightEvents' ambient modifiers. Controller = scripts/Visitors.gd; the wave-edge gate is
# kept pure in scripts/logic/VisitorsLogic.gd (BasementLogic.gd's own "kept pure so it's
# probe-able" rationale, mirrored verbatim). GATE-FIRST: only a gate PASS ever reaches
# RunConfig.rand_float() (the Basement door precedent — Daily Shift determinism is preserved by
# never spending a seeded roll on a wave-edge the gate would have blocked anyway).
const VISITOR_MIN_WAVE := 4              # first wave a visitor can roll at a wave-edge
const VISITOR_CHANCE := 0.20             # chance roll once the gate passes (RunConfig.rand_float — Daily stays seeded)
const VISITOR_COOLDOWN := 90.0           # seconds after a visitor ARRIVES before the next roll is even gate-eligible
const VISITOR_MAX_PER_RUN := 2           # visitors per run, of 3 possible kinds — no repeats (VisitorsLogic.pick)
const VISITOR_SPAWN_DIST := SPAWN_RADIUS # CRYPTID's spawn-ring distance — reuses Spawner's own off-screen-entry tuning (SPAWN_RADIUS's doc comment) rather than a redundant near-duplicate constant

# --- THE CRYPTID (Night Shift Stories v0.1.68): a bounty that flees ---
const CRYPTID_HP := 900.0                # takes full damage — no talent immunity, per spec
const CRYPTID_COINS := 250               # RunStats.add_coins on a kill inside CRYPTID_WINDOW (+ a crate — see BasementLogic.crate_id_for)
const CRYPTID_WINDOW := 20.0             # seconds alive before it despawns uncaught ("IT'S GONE")
const CRYPTID_MOVE_SPEED := 130.0        # px/sec flee speed — above a runner's ~119 (ENEMY_MOVE_SPEED 70 x the runner row's 1.7 spd_mult), genuinely hard to run down

# --- THE DRIVE-BY (Night Shift Stories v0.1.68): a lane of consequences ---
const DRIVEBY_TELEGRAPH := 2.0           # seconds of siren + lane telegraph before the lane goes live
const DRIVEBY_ACTIVE := 4.0              # seconds the lane deals damage — 2 + 4 = the spec's 6s total
const DRIVEBY_DPS := 80.0                # damage/sec to anything in-lane (enemies AND the player), ticked at HAZARD_TICK_INTERVAL (~5Hz)
const DRIVEBY_THICKNESS := 90.0          # px half-width of the damaging lane — a lane, not a beam (compare AIMED_BAND_THICKNESS's 26px)
const DRIVEBY_LANE_LENGTH := 2400.0      # px lane length, centered on the telegraphed aim-point snapshot — crosses the arena from any reasonable spawn point
