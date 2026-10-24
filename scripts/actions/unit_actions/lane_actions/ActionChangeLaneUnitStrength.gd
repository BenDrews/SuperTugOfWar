## Changes the strength of every unit in the picked lanes (clamped at 0).
## Values:
## - strength_change: int. Default 1.
## - unit_owner_filter: int (Unit.UNIT_OWNERS, or -1 for both sides). Default -1.
extends BaseLaneAction

func perform_action() -> void:
	var action_interceptor_processors: Array[ActionInterceptorProcessor] = _intercept_action([])
	for action_interceptor_processor: ActionInterceptorProcessor in action_interceptor_processors:
		var strength_change: int = action_interceptor_processor.get_shadowed_action_values("strength_change", 1)
		for unit: Unit in _get_affected_units():
			unit.change_strength(strength_change)

func _to_string() -> String:
	return "Change Lane Unit Strength Action: " + str(get_action_value("strength_change", 1))
