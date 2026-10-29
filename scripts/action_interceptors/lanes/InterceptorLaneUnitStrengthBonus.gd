## Lane status interceptor: units placed in this lane, on the status's side, start with extra strength
## equal to the status's charges. Registered by status_effect_lane_unit_strength on a lane side.
extends BaseActionInterceptor

const STATUS_EFFECT_ID: String = "status_effect_lane_unit_strength"

func process_action_interception(action_interceptor_processor: ActionInterceptorProcessor, _preview_mode: bool = false) -> int:
	var status_holder: StatusEffectHolder = source as StatusEffectHolder
	if status_holder == null:
		return ACTION_ACCEPTENCES.CONTINUE
	var strength: int = action_interceptor_processor.get_shadowed_action_values(CardData.UNIT_STRENGTH_KEY, 0)
	action_interceptor_processor.set_shadowed_action_values(CardData.UNIT_STRENGTH_KEY, strength + status_holder.get_status_charges(STATUS_EFFECT_ID))
	return ACTION_ACCEPTENCES.CONTINUE
