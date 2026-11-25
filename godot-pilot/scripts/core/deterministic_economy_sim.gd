class_name DeterministicEconomySim
extends RefCounted
## Pure Deterministic Economy, Harmony & Monument Simulation Kernel (`gamedev-core` Rule 1):
## - Zero Node3D dependencies; 100% unit-testable at 1000x speed in headless CI!
## - Full snapshot `to_dict()` / `from_dict()` serialization for `CampaignSaveV3`.

var cfg: ChapterBalanceResource
var days_remaining: float = 240.0
var monument_pct: float = 0.0
var res_primary: float = 45.0     # Ch00: Timber | Ch01: Water
var res_secondary: float = 15.0   # Ch00: Pitch  | Ch01: Firewood/Stone
var res_tertiary: float = 60.0    # Ch00: Food   | Ch01: Flock/Fodder
var harmony: float = 84.0
var pasture_pressure: float = 35.0

var w_gather: int = 2
var w_build: int = 3
var w_craft: int = 1
var w_guard: int = 1

var inspection_boost_timer: float = 0.0
var palisade_pct: float = 0.0
var palisade_hp: float = 0.0
var palisade_building: bool = false
var fire_intensity: float = 0.0
var choice_history: Array[String] = []


func _init(balance: ChapterBalanceResource = null) -> void:
	cfg = balance if balance != null else ChapterBalanceResource.new()
	days_remaining = cfg.total_countdown_days


## Exact V6 Harmony Work-Efficiency Curve: clamp(0.75 + (harmony - 50)/100 * 0.8, 0.75, 1.35)
func harmony_multiplier() -> float:
	return clampf(0.75 + ((harmony - 50.0) / 100.0) * 0.80, 0.75, 1.35)


func progressive_step_index() -> int:
	if monument_pct <= 0.01:
		return 0
	return clampi(int(ceil(monument_pct / 100.0 * float(maxi(1, cfg.progressive_steps)))), 1, cfg.progressive_steps)


func assign_worker(role: String, delta_v: int, max_workers: int = 7) -> void:
	var pool: int = max_workers - (w_gather + w_build + w_craft + w_guard)
	if delta_v > 0 and pool <= 0:
		if role != "log" and w_gather > 1: w_gather -= 1
		elif role != "build" and w_build > 1: w_build -= 1
		elif role != "pitch" and w_craft > 0: w_craft -= 1
		elif role != "guard" and w_guard > 0: w_guard -= 1
		else: return
	match role:
		"log": w_gather = clampi(w_gather + delta_v, 0, max_workers)
		"build": w_build = clampi(w_build + delta_v, 0, max_workers)
		"pitch": w_craft = clampi(w_craft + delta_v, 0, max_workers)
		"guard": w_guard = clampi(w_guard + delta_v, 0, max_workers)


func deposit_gathered_trip(base_amount: float = -1.0) -> int:
	var amt: float = base_amount if base_amount > 0.0 else cfg.primary_yield_per_trip
	var gained: int = maxi(1, int(roundf(amt * harmony_multiplier())))
	res_primary += float(gained)
	return gained


func tick(dt: float) -> Dictionary:
	var result: Dictionary = {"shortage": false, "burned": 0.0}
	if dt <= 0.0:
		return result
	days_remaining = maxf(0.0, days_remaining - dt)
	if inspection_boost_timer > 0.0:
		inspection_boost_timer = maxf(0.0, inspection_boost_timer - dt)

	var h_mul: float = harmony_multiplier()
	res_secondary += float(w_craft) * cfg.secondary_rate_per_worker_sec * h_mul * dt
	res_tertiary += float(w_craft) * cfg.tertiary_rate_per_worker_sec * h_mul * dt

	var need: float = float(w_build) * cfg.build_primary_cost_per_worker_sec * dt
	if w_build > 0:
		if res_primary >= need:
			res_primary -= need
			var boost: float = cfg.inspection_boost_mul if inspection_boost_timer > 0.0 else 1.0
			monument_pct = minf(100.0, monument_pct + float(w_build) * cfg.build_pct_per_worker_sec * boost * h_mul * dt)
		else:
			result["shortage"] = true

	if fire_intensity > 0.01:
		var burn: float = cfg.fire_burn_per_sec * fire_intensity * dt
		res_primary = maxf(0.0, res_primary - burn)
		result["burned"] = burn
	return result


func to_dict() -> Dictionary:
	return {
		"daysRemaining": days_remaining,
		"monumentPct": monument_pct,
		"resPrimary": res_primary,
		"resSecondary": res_secondary,
		"resTertiary": res_tertiary,
		"harmony": harmony,
		"pasturePressure": pasture_pressure,
		"workers": {"log": w_gather, "build": w_build, "pitch": w_craft, "guard": w_guard},
		"palisadePct": palisade_pct,
		"palisadeHp": palisade_hp,
		"palisadeBuilding": palisade_building,
		"fireIntensity": fire_intensity,
		"choiceHistory": choice_history.duplicate(),
	}


func from_dict(d: Dictionary) -> void:
	days_remaining = float(d.get("daysRemaining", cfg.total_countdown_days))
	monument_pct = float(d.get("monumentPct", 0.0))
	res_primary = float(d.get("resPrimary", 45.0))
	res_secondary = float(d.get("resSecondary", 15.0))
	res_tertiary = float(d.get("resTertiary", 60.0))
	harmony = float(d.get("harmony", 84.0))
	pasture_pressure = float(d.get("pasturePressure", 35.0))
	var wk: Dictionary = d.get("workers", {})
	w_gather = int(wk.get("log", w_gather))
	w_build = int(wk.get("build", w_build))
	w_craft = int(wk.get("pitch", w_craft))
	w_guard = int(wk.get("guard", w_guard))
	palisade_pct = float(d.get("palisadePct", 0.0))
	palisade_hp = float(d.get("palisadeHp", 0.0))
	palisade_building = bool(d.get("palisadeBuilding", false))
	fire_intensity = float(d.get("fireIntensity", 0.0))
	choice_history.clear()
	for c in d.get("choiceHistory", []):
		choice_history.append(str(c))
