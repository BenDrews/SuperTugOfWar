## Changes the strength of every unit in the picked lanes (clamped at 0).
## Each unit is intercepted separately, with its lane's and its own statuses (see BaseLaneAction).
## Values:
## - strength_change: int. Default 1.
## - unit_owner_filter: int (Unit.UNIT_OWNERS, or -1 for both sides). Default -1, or the status's
##   side when run by a lane status.
extends BaseLaneAction

func perform_action() -> void:
	for unit: Unit in _get_affected_units():
		for action_interceptor_processor: ActionInterceptorProcessor in _intercept_for_unit(unit):
			var strength_change: int = action_interceptor_processor.get_shadowed_action_values("strength_change", 1)
			unit.change_strength(strength_change)

func _to_string() -> String:
	return "Change Lane Unit Strength Action: " + str(get_action_value("strength_change", 1))
