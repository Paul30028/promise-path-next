class_name ChapterBalanceResource
extends Resource
## Strongly-Typed Balance Resource (.tres) for Cartridge Chapters — ZERO hardcoded script numbers!

@export var chapter_id: String = "ch00_noah_ark"
@export var total_countdown_days: float = 240.0
@export var tree_count: int = 30
@export var tree_chop_hits: int = 4
@export var chop_interval_sec: float = 1.1
@export var primary_yield_per_trip: float = 12.0
@export var stump_regrow_sec: float = 45.0
@export var progressive_steps: int = 30
@export var build_primary_cost_per_worker_sec: float = 2.4
@export var build_pct_per_worker_sec: float = 1.45
@export var secondary_rate_per_worker_sec: float = 2.0
@export var tertiary_rate_per_worker_sec: float = 1.6
@export var inspection_boost_mul: float = 1.6
@export var inspection_boost_sec: float = 22.0
@export var palisade_build_cost: float = 40.0
@export var palisade_repair_cost: float = 20.0
@export var palisade_max_hp: float = 300.0
@export var fire_burn_per_sec: float = 3.5
@export var water_douse_pct: float = 50.0
@export var tactical_time_scale: float = 0.35
@export var rain_mud_speed_mul: float = 0.85

# Gameplay 2.0: Upkeep, Companion Stamina, Shofar, Command Pips & Workshop Tech Tree
@export var upkeep_per_worker_sec: float = 0.14
@export var stamina_drain_per_sec: float = 1.45
@export var stamina_rest_recover_sec: float = 8.5
@export var shofar_cooldown_sec: float = 18.0
@export var shofar_buff_sec: float = 6.5
@export var shofar_speed_mul: float = 1.30
@export var command_pip_max: int = 3
@export var command_pip_regen_sec: float = 20.0
@export var upgrade_costs_primary: PackedFloat32Array = PackedFloat32Array([28.0, 20.0, 24.0])
@export var upgrade_costs_secondary: PackedFloat32Array = PackedFloat32Array([0.0, 10.0, 0.0])
