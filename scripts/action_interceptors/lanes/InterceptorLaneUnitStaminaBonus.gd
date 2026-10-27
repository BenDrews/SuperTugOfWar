## Lane status interceptor: units placed in this lane, on the status's side, start with extra stamina
## equal to the status's charges. Registered by status_effect_lane_unit_stamina on a lane side, and
## picked up by ActionSummonUnit through its destination lane (BaseAction.get_status_context_holders()).
extends BaseActionInterceptor

const STATUS_EFFECT_ID: String = "status_effect_lane_unit_stamina"

func process_action_interception(action_interceptor_processor: ActionInterceptorProcessor, _preview_mode: bool = false) -> int:
	var status_holder: StatusEffectHolder = source as StatusEffectHolder
	if status_holder == null:
		return ACTION_ACCEPTENCES.CONTINUE
	var stamina: int = action_interceptor_processor.get_shadowed_action_values(CardData.UNIT_STAMINA_KEY, 1)
	action_interceptor_processor.set_shadowed_action_values(CardData.UNIT_STAMINA_KEY, stamina + status_holder.get_status_charges(STATUS_EFFECT_ID))
	return ACTION_ACCEPTENCES.CONTINUE
