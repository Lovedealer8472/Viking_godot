# ═══════════════════════════════════════════════════════════════════════════
# Herd system — animal profiles, winter fodder, breeding.
# Ported from src/sim/herd.ts.
# ═══════════════════════════════════════════════════════════════════════════
class_name SimHerd
extends RefCounted

# ── Animal profiles ──────────────────────────────────────────────────────

static func animal_profile(animal: int) -> Dictionary:
	match animal:
		GameTypes.AnimalType.CATTLE:   return {"label": "Cattle",   "hay": 2.0, "food": 1.2, "prestige": 4, "breed": 0.05}
		GameTypes.AnimalType.SHEEP:    return {"label": "Sheep",   "hay": 0.6, "food": 0.5, "prestige": 1, "breed": 0.12}
		GameTypes.AnimalType.GOATS:    return {"label": "Goats",   "hay": 0.5, "food": 0.5, "prestige": 1, "breed": 0.13}
		GameTypes.AnimalType.HORSES:   return {"label": "Horses",  "hay": 1.4, "food": 0.2, "prestige": 3, "breed": 0.04}
		GameTypes.AnimalType.PIGS:     return {"label": "Pigs",    "hay": 0.4, "food": 0.9, "prestige": 1, "breed": 0.1}
		GameTypes.AnimalType.CHICKENS: return {"label": "Chickens","hay": 0.1, "food": 0.3, "prestige": 0, "breed": 0.15}
	return {}

# ── Hay demand ────────────────────────────────────────────────────────────

static func hay_demand_per_week(herd: Dictionary) -> float:
	var total := 0.0
	for animal in herd:
		var count: int = herd[animal]
		var profile := animal_profile(animal)
		total += count * profile["hay"]
	return snapped(total, 0.1)

# ── Food yield ────────────────────────────────────────────────────────────

static func herd_food_yield(herd: Dictionary, tended: bool) -> float:
	var total := 0.0
	for animal in herd:
		var count: int = herd[animal]
		var profile := animal_profile(animal)
		total += count * profile["food"]
	var mult := 1.0 if tended else 0.5
	return snapped(total * mult, 0.1)

# ── Herd prestige ─────────────────────────────────────────────────────────

static func herd_prestige(herd: Dictionary) -> int:
	var total := 0
	for animal in herd:
		var count: int = herd[animal]
		total += count * animal_profile(animal)["prestige"]
	return total

# ── Winter fodder (the Floki trap) ────────────────────────────────────────

static func consume_winter_fodder(herd: Dictionary, hay_available: float, rng: Callable) -> Dictionary:
	var demand := hay_demand_per_week(herd)
	var next := herd.duplicate()
	var losses := {}
	var total_losses := 0

	if demand <= 0 or hay_available >= demand:
		return {"herd": next, "consumed": min(hay_available, demand), "losses": losses, "total": 0}

	var coverage := hay_available / demand
	var ordered := [GameTypes.AnimalType.CATTLE, GameTypes.AnimalType.HORSES,
		GameTypes.AnimalType.SHEEP, GameTypes.AnimalType.GOATS,
		GameTypes.AnimalType.PIGS, GameTypes.AnimalType.CHICKENS]

	for animal in ordered:
		if next[animal] <= 0: continue
		var profile := animal_profile(animal)
		var rate: float = (1.0 - coverage) * (0.4 + float(profile["hay"]) * 0.15)
		var dead := 0
		for i in next[animal]:
			if rng.call() < rate: dead += 1
		if dead > 0:
			next[animal] -= dead
			losses[animal] = dead
			total_losses += dead

	return {"herd": next, "consumed": hay_available, "losses": losses, "total": total_losses}

# ── Breeding ──────────────────────────────────────────────────────────────

static func breed_herd(herd: Dictionary, healthy: bool, rng: Callable) -> Dictionary:
	if not healthy: return herd.duplicate()
	var next := herd.duplicate()
	for animal in next:
		var profile := animal_profile(animal)
		for i in herd[animal]:
			if rng.call() < profile["breed"]: next[animal] += 1
	return next
