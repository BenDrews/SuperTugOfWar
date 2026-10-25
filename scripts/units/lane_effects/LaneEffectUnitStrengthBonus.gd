## Units placed in this lane start with extra strength.
extends BaseLaneEffect

func modify_unit_summon(summon: Dictionary) -> void:
	if affects_owner(summon.unit_owner):
		summon.unit_strength = max(summon.unit_strength + amount, 0)

func get_badge_text() -> String:
	return "%+d STR" % amount

func get_description() -> String:
	return "%s\n%s placed in this lane start with %+d strength" % [values.get("lane_effect_name", "Strength"), _get_owner_text(), amount]
