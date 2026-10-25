## Units placed in this lane start with extra stamina.
extends BaseLaneEffect

func modify_unit_summon(summon: Dictionary) -> void:
	if affects_owner(summon.unit_owner):
		summon.unit_stamina += amount

func get_badge_text() -> String:
	return "%+d STA" % amount

func get_description() -> String:
	return "%s\n%s placed in this lane start with %+d stamina" % [values.get("lane_effect_name", "Stamina"), _get_owner_text(), amount]
