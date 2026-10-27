## A simplified interceptable clone of ActionApplyStatus that's intended for use in StatusEffectHolder._decay_status_effect()
## Used as an instant intercepted action and not put onto the ActionHandler stack.
## To intercept, extend InterceptorBaseNegateStatusDecay and provide a check for status_object_id.
## Works on combatant targets, or on lane/unit status holders passed in the status_holders value.
extends BaseAction

func perform_action():
	# lane / unit statuses
	var status_holders: Array = get_action_value("status_holders", [])
	if len(status_holders) > 0:
		for action_interceptor_processor in _intercept_action([]):
			var status_charge_amount: int = action_interceptor_processor.get_shadowed_action_values("status_charge_amount", 1)
			var status_effect_object_id: String = action_interceptor_processor.get_shadowed_action_values("status_effect_object_id", "")
			for status_holder: StatusEffectHolder in status_holders:
				status_holder.add_status_effect_charges(status_effect_object_id, status_charge_amount, 0)
		return
	
	var action_interceptor_processors: Array[ActionInterceptorProcessor] = _intercept_action()
	
	for action_interceptor_processor in action_interceptor_processors:
		var target: BaseCombatant = action_interceptor_processor.target
		if target == null:
			return
		
		var status_charge_amount: int = action_interceptor_processor.get_shadowed_action_values("status_charge_amount", 1)
		var status_effect_object_id: String = action_interceptor_processor.get_shadowed_action_values("status_effect_object_id", "")
		target.add_status_effect_charges(status_effect_object_id, status_charge_amount, 0)

## Interceptors on the decaying lane/unit statuses' own holders apply too.
func get_status_context_holders() -> Array[Object]:
	var holders: Array[Object] = []
	holders.assign(get_action_value("status_holders", []))
	return holders

func is_instant_action() -> bool:
	return true

func is_action_short_circuited() -> bool:
	return get_action_value("action_short_circuits", true)

func _to_string():
	var status_charge_amount: int = get_action_value("status_charge_amount", 0)
	var status_effect_object_id: String = get_action_value("status_effect_object_id", "")
	return "Decay Status Action: " + status_effect_object_id + " " + str(status_charge_amount)
