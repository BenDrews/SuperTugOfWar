## Changes the stamina of every unit in the picked lanes. Units brought to 0 stamina are discarded.
## Values:
## - stamina_change: int. Negative to tire units, positive to refresh them. Default -1.
## - unit_owner_filter: int (Unit.UNIT_OWNERS, or -1 for both sides). Default -1.
extends BaseLaneAction

func perform_action() -> void:
	var action_interceptor_processors: Array[ActionInterceptorProcessor] = _intercept_action([])
	for action_interceptor_processor: ActionInterceptorProcessor in action_interceptor_processors:
		var stamina_change: int = action_interceptor_processor.get_shadowed_action_values("stamina_change", -1)
		for unit: Unit in _get_affected_units():
			unit.change_stamina(stamina_change)
			if unit.unit_stamina <= 0:
				unit.discard_unit()

func _to_string() -> String:
	return "Change Lane Unit Stamina Action: " + str(get_action_value("stamina_change", -1))
