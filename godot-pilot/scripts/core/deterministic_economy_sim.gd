class_name DeterministicEconomySim
extends RefCounted
## Pure Deterministic Gameplay 2.0 Economy, Companion Stamina, Workshop Tech Tree & Mutator Kernel:
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

# Gameplay 2.0 State: Companion Traits & Stamina, Shofar, Command Pips, Workshop Upgrades & Mutators
var companions: Array[Dictionary] = []
var upgrades_unlocked: Array[bool] = [false, false, false]
var command_pips: int = 2
var pip_regen_timer: float = 0.0
var shofar_cd: float = 0.0
var shofar_buff_timer: float = 0.0
var fireproof_timer: float = 0.0
var double_shift_timer: float = 0.0
var deluge_emergency: bool = false
var mutator_drought: bool = false
var mutator_imminent: bool = false
var mutator_pacifist: bool = false


func _init(balance: ChapterBalanceResource = null) -> void:
	cfg = balance if balance != null else ChapterBalanceResource.new()
	days_remaining = cfg.total_countdown_days


func apply_trial_mutators(mutators: Dictionary) -> void:
	mutator_drought = bool(mutators.get("drought", false))
	mutator_imminent = bool(mutators.get("imminent", false))
	mutator_pacifist = bool(mutators.get("pacifist", false))
	if mutator_drought:
		res_primary = roundf(res_primary * 0.75)
	if mutator_imminent:
		days_remaining = roundf(days_remaining * 0.70)


func setup_companions(cast_cfg: Array) -> void:
	companions.clear()
	var default_traits: Array[Dictionary] = [
		{"trait_key": "TRT_LEADER", "role": "lead", "bonus": 0.15},
		{"trait_key": "TRT_HEARTH", "role": "rest", "bonus": 0.35},
		{"trait_key": "TRT_MORTISE", "role": "build", "bonus": 0.25},
		{"trait_key": "TRT_MIGHT", "role": "log", "bonus": 0.30},
		{"trait_key": "TRT_SCOUT", "role": "pitch", "bonus": 0.28},
		{"trait_key": "TRT_WEAVE", "role": "pitch", "bonus": 0.15},
		{"trait_key": "TRT_SHEPHERD", "role": "guard", "bonus": 0.22},
		{"trait_key": "TRT_GATHER", "role": "log", "bonus": 0.16},
	]
	for i in range(maxi(1, cast_cfg.size())):
		var ci: Dictionary = cast_cfg[i] if i < cast_cfg.size() else {}
		var td: Dictionary = default_traits[mini(i, default_traits.size() - 1)]
		companions.append({
			"idx": i,
			"name_zh": str(ci.get("nameZh", "同伴 %d" % i)),
			"name_en": str(ci.get("nameEn", "Companion %d" % i)),
			"trait_key": str(ci.get("traitKey", td["trait_key"])),
			"role": str(ci.get("affinityRole", td["role"])),
			"bonus": float(ci.get("affinityBonus", td["bonus"])),
			"stamina": 100.0,
			"resting": false,
		})


## Exact V6 Harmony Work-Efficiency Curve + Shofar Rally Multiplier
func harmony_multiplier() -> float:
	var base_m: float = clampf(0.75 + ((harmony - 50.0) / 100.0) * 0.80, 0.75, 1.35)
	return base_m * (cfg.shofar_speed_mul if shofar_buff_timer > 0.0 else 1.0)


func role_trait_multiplier(role_name: String) -> float:
	var mul: float = 1.0
	for i in range(1, companions.size()):
		var c: Dictionary = companions[i]
		if not bool(c.get("resting", false)) and str(c.get("role", "")) == role_name:
			mul += float(c.get("bonus", 0.0)) * 0.5
	return minf(1.55, mul)


func companion_speed_scale(comp_idx: int) -> float:
	var s_mul: float = cfg.shofar_speed_mul if shofar_buff_timer > 0.0 else 1.0
	if comp_idx < 0 or comp_idx >= companions.size():
		return s_mul
	var st: float = float(companions[comp_idx].get("stamina", 100.0))
	return s_mul * (0.58 if st < 28.0 else 1.0)


func toggle_companion_rest(comp_idx: int) -> bool:
	if comp_idx <= 0 or comp_idx >= companions.size():
		return false
	companions[comp_idx]["resting"] = not bool(companions[comp_idx].get("resting", false))
	return bool(companions[comp_idx]["resting"])


func resting_companion_count() -> int:
	var cnt: int = 0
	for i in range(1, companions.size()):
		if bool(companions[i].get("resting", false)):
			cnt += 1
	return cnt


func average_stamina() -> float:
	if companions.size() <= 1:
		return 100.0
	var sum_s: float = 0.0
	for i in range(1, companions.size()):
		sum_s += float(companions[i].get("stamina", 100.0))
	return sum_s / float(companions.size() - 1)


func trigger_shofar() -> bool:
	if shofar_cd > 0.0:
		return false
	shofar_cd = cfg.shofar_cooldown_sec
	shofar_buff_timer = cfg.shofar_buff_sec
	for i in range(companions.size()):
		companions[i]["stamina"] = minf(100.0, float(companions[i].get("stamina", 100.0)) + 18.0)
		if float(companions[i]["stamina"]) >= 45.0:
			companions[i]["resting"] = false
	return true


func upgrade_cost(slot_idx: int) -> Vector2:
	var cp: float = cfg.upgrade_costs_primary[slot_idx] if slot_idx < cfg.upgrade_costs_primary.size() else 24.0
	var cs: float = cfg.upgrade_costs_secondary[slot_idx] if slot_idx < cfg.upgrade_costs_secondary.size() else 0.0
	return Vector2(cp, cs)


func can_unlock_upgrade(slot_idx: int) -> bool:
	if slot_idx < 0 or slot_idx >= upgrades_unlocked.size() or upgrades_unlocked[slot_idx]:
		return false
	var c: Vector2 = upgrade_cost(slot_idx)
	return res_primary >= c.x and res_secondary >= c.y


func unlock_upgrade(slot_idx: int) -> bool:
	if not can_unlock_upgrade(slot_idx):
		return false
	var c: Vector2 = upgrade_cost(slot_idx)
	res_primary -= c.x
	res_secondary -= c.y
	upgrades_unlocked[slot_idx] = true
	harmony = minf(100.0, harmony + 3.0)
	return true


func spend_pips(cost: int) -> bool:
	if command_pips < cost:
		return false
	command_pips -= cost
	return true


func gain_pip(amount: int = 1) -> void:
	command_pips = clampi(command_pips + amount, 0, cfg.command_pip_max)


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
	var gained: int = maxi(1, int(roundf(amt * harmony_multiplier() * role_trait_multiplier("log"))))
	res_primary += float(gained)
	return gained


func tick(dt: float) -> Dictionary:
	var result: Dictionary = {"shortage": false, "burned": 0.0, "deluge": false, "starving": false}
	if dt <= 0.0:
		return result
	days_remaining = maxf(0.0, days_remaining - dt)
	if inspection_boost_timer > 0.0: inspection_boost_timer = maxf(0.0, inspection_boost_timer - dt)
	if shofar_cd > 0.0: shofar_cd = maxf(0.0, shofar_cd - dt)
	if shofar_buff_timer > 0.0: shofar_buff_timer = maxf(0.0, shofar_buff_timer - dt)
	if fireproof_timer > 0.0: fireproof_timer = maxf(0.0, fireproof_timer - dt)
	if double_shift_timer > 0.0: double_shift_timer = maxf(0.0, double_shift_timer - dt)

	# Command Pip regeneration
	if command_pips < cfg.command_pip_max:
		pip_regen_timer += dt
		if pip_regen_timer >= cfg.command_pip_regen_sec:
			pip_regen_timer -= cfg.command_pip_regen_sec
			command_pips = mini(cfg.command_pip_max, command_pips + 1)

	# Companion Stamina drain & Shelter Rest rotation
	var rain_harsh: bool = (days_remaining < 35.0 and cfg.chapter_id == "ch00_noah_ark")
	var drain_mul: float = (1.55 if rain_harsh else 1.0) * (0.50 if upgrades_unlocked[2] else 1.0)
	var rest_mul: float = (1.60 if upgrades_unlocked[2] else 1.0) * 1.25
	var active_ratio: float = 1.0
	if companions.size() > 1:
		var working_cnt: int = 0
		for i in range(1, companions.size()):
			var c: Dictionary = companions[i]
			var st: float = float(c.get("stamina", 100.0))
			if bool(c.get("resting", false)):
				st = minf(100.0, st + cfg.stamina_rest_recover_sec * rest_mul * dt)
				if st >= 94.0:
					c["resting"] = false
			else:
				working_cnt += 1
				st = maxf(8.0, st - cfg.stamina_drain_per_sec * drain_mul * dt)
				if st <= 20.0:
					c["resting"] = true
			c["stamina"] = st
		active_ratio = clampf(float(working_cnt) / float(companions.size() - 1), 0.35, 1.0)

	# Real Provisions / Water Upkeep
	var upkeep_mul: float = 1.50 if mutator_drought else 1.0
	var upkeep_need: float = float(w_gather + w_build + w_guard) * cfg.upkeep_per_worker_sec * upkeep_mul * (0.55 if upgrades_unlocked[2] else 1.0) * dt
	if cfg.chapter_id == "ch00_noah_ark":
		if res_tertiary >= upkeep_need:
			res_tertiary -= upkeep_need
		else:
			res_tertiary = 0.0
			harmony = maxf(42.0, harmony - 0.55 * dt)
			result["starving"] = true
	else:
		if res_primary >= upkeep_need:
			res_primary -= upkeep_need
		else:
			res_primary = 0.0
			pasture_pressure = minf(98.0, pasture_pressure + 1.4 * dt)
			result["starving"] = true

	var h_mul: float = harmony_multiplier() * active_ratio
	var kiln_mul: float = 1.85 if upgrades_unlocked[1] else 1.0
	res_secondary += float(w_craft) * cfg.secondary_rate_per_worker_sec * kiln_mul * role_trait_multiplier("pitch") * h_mul * dt
	res_tertiary += float(w_craft) * cfg.tertiary_rate_per_worker_sec * kiln_mul * h_mul * dt

	var crane_cost_mul: float = 0.75 if upgrades_unlocked[0] else 1.0
	var crane_spd_mul: float = (1.22 if upgrades_unlocked[0] else 1.0) * (1.65 if double_shift_timer > 0.0 else 1.0)
	var need: float = float(w_build) * cfg.build_primary_cost_per_worker_sec * crane_cost_mul * dt
	if w_build > 0:
		if res_primary >= need:
			res_primary -= need
			var boost: float = cfg.inspection_boost_mul if inspection_boost_timer > 0.0 else 1.0
			monument_pct = minf(100.0, monument_pct + float(w_build) * cfg.build_pct_per_worker_sec * crane_spd_mul * role_trait_multiplier("build") * boost * h_mul * dt)
		else:
			result["shortage"] = true

	# Countdown Zero Deluge Emergency (real Frostpunk urgency without hard lock!)
	if days_remaining <= 0.01 and monument_pct < 99.9 and cfg.chapter_id == "ch00_noah_ark":
		deluge_emergency = true
		result["deluge"] = true
		res_primary = maxf(4.0, res_primary - 0.42 * dt)
		harmony = maxf(45.0, harmony - 0.30 * dt)
	else:
		deluge_emergency = false

	if fireproof_timer > 0.0:
		fire_intensity = 0.0
	elif fire_intensity > 0.01:
		var f_mul: float = 0.40 if upgrades_unlocked[1] else 1.0
		var burn: float = cfg.fire_burn_per_sec * fire_intensity * f_mul * dt
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
		"upgradesUnlocked": upgrades_unlocked.duplicate(),
		"commandPips": command_pips,
		"companions": companions.duplicate(true),
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
	command_pips = int(d.get("commandPips", 2))
	var upg: Variant = d.get("upgradesUnlocked", [])
	if upg is Array and upg.size() == 3:
		for i in range(3):
			upgrades_unlocked[i] = bool(upg[i])
	var cps: Variant = d.get("companions", [])
	if cps is Array and not cps.is_empty():
		companions.clear()
		for c in cps:
			if c is Dictionary:
				companions.append((c as Dictionary).duplicate(true))
	choice_history.clear()
	for c in d.get("choiceHistory", []):
		choice_history.append(str(c))
