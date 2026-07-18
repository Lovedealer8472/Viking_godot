# ═══════════════════════════════════════════════════════════════════════════
# Resources — weekly upkeep, weather, and resource math.
# Ported from src/sim/resources.ts.
# ═══════════════════════════════════════════════════════════════════════════
class_name SimResources
extends RefCounted

# ── Weather ───────────────────────────────────────────────────────────────

static func roll_weather(week: int, rng: Callable) -> int:
	var season := GameTypes.week_to_season(week)
	var roll: float = rng.call()
	match season:
		GameTypes.Season.WINTER:
			if roll < 0.35: return GameTypes.Weather.EXTREME
			if roll < 0.7: return GameTypes.Weather.HARSH
			return GameTypes.Weather.FAIR
		GameTypes.Season.AUTUMN:
			if roll < 0.25: return GameTypes.Weather.HARSH
			return GameTypes.Weather.FAIR
		_:
			if roll < 0.1: return GameTypes.Weather.HARSH
			return GameTypes.Weather.FAIR

static func apply_difficulty_to_weather(weather: int, pressure: float) -> int:
	if pressure <= -0.1:
		if weather == GameTypes.Weather.EXTREME: return GameTypes.Weather.HARSH
		if weather == GameTypes.Weather.HARSH: return GameTypes.Weather.FAIR
	if pressure >= 0.18:
		if weather == GameTypes.Weather.FAIR: return GameTypes.Weather.HARSH
		if weather == GameTypes.Weather.HARSH: return GameTypes.Weather.EXTREME
	if pressure >= 0.1 and weather == GameTypes.Weather.FAIR: return GameTypes.Weather.HARSH
	return weather

# ── Upkeep ────────────────────────────────────────────────────────────────

static func weekly_upkeep(pop: int, season: int, weather: int, shelter: float, pressure: float = 1.0) -> Dictionary:
	var winter_mult := 1.0
	if season == GameTypes.Season.WINTER: winter_mult = 1.4
	elif season == GameTypes.Season.AUTUMN: winter_mult = 1.1

	var weather_fuel_mult := 1.0
	if weather == GameTypes.Weather.EXTREME: weather_fuel_mult = 1.5
	elif weather == GameTypes.Weather.HARSH: weather_fuel_mult = 1.2

	var shelter_food_save := 1.0
	if shelter >= 2: shelter_food_save = 0.9
	elif shelter >= 1: shelter_food_save = 0.95

	var food_cost: int = -ceili(pop * 1.0 * winter_mult * shelter_food_save * pressure)

	var fuel_cost: float
	if season == GameTypes.Season.WINTER or season == GameTypes.Season.AUTUMN:
		fuel_cost = -ceil(pop * 0.6 * weather_fuel_mult * (1.0 - shelter * 0.08) * pressure)
	else:
		fuel_cost = -ceil(pop * 0.15 * pressure)

	var morale_delta := -2 if season == GameTypes.Season.WINTER else 0

	return {"food": food_cost, "fuel": fuel_cost, "morale": morale_delta}

# ── Difficulty profiles ──────────────────────────────────────────────────

static func difficulty_profile(diff: int) -> Dictionary:
	match diff:
		GameTypes.Difficulty.EASY:
			return {"upkeep": 0.85, "weather": -0.12, "injury": 0.75, "harsh": 0.75, "sailing": 0.7, "nav": 0.8}
		GameTypes.Difficulty.NORMAL:
			return {"upkeep": 1.0, "weather": 0.0, "injury": 1.0, "harsh": 1.0, "sailing": 1.0, "nav": 1.0}
		GameTypes.Difficulty.BRUTAL:
			return {"upkeep": 1.16, "weather": 0.12, "injury": 1.25, "harsh": 1.25, "sailing": 1.25, "nav": 1.2}
		GameTypes.Difficulty.VIKING:
			return {"upkeep": 1.32, "weather": 0.2, "injury": 1.55, "harsh": 1.55, "sailing": 1.45, "nav": 1.4}
	return {}

# ── Clamp ─────────────────────────────────────────────────────────────────

static func clampf(v: float, lo: float, hi: float) -> float:
	return max(lo, min(hi, v))

static func clampf3(v: float) -> float:  # shelter clamp
	return clampf(v, 0.0, 3.0)
