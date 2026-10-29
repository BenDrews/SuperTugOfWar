## Changes the stamina of every unit in the picked lanes. Units brought to 0 stamina are discarded.
## Each unit is intercepted separately, with its lane's and its own statuses (see BaseLaneAction).
## Values:
## - stamina_change: int. Negative to tire units, positive to refresh them. Default -1.
## - unit_owner_filter: int (Unit.UNIT_OWNERS, or -1 for both sides). Default -1, or the status's
##   side when run by a lane status.
extends BaseLaneAction

func perform_action() -> void:
	for unit: Unit in _get_affected_units():
		for action_interceptor_processor: ActionInterceptorProcessor in _intercept_for_unit(unit):
			var stamina_change: int = action_interceptor_processor.get_shadowed_action_values("stamina_change", -1)
			unit.change_stamina(stamina_change)
			if unit.unit_stamina <= 0:
				unit.discard_unit()

func _to_string() -> String:
	return "Change Lane Unit Stamina Action: " + str(get_action_value("stamina_change", -1))
