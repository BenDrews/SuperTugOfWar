## Placement interceptor (ActionUnitPlacement) for status_effect_lane_spearhead: units on the status's
## side that end up placed in this lane go to the front of the line. Runs after lane redirects
## (lower priority), so units moved into this lane also go to the front.
extends BaseActionInterceptor

func process_action_interception(action_interceptor_processor: ActionInterceptorProcessor, _preview_mode: bool = false) -> int:
	var status_holder: StatusEffectHolder = source as StatusEffectHolder
	if status_holder == null:
		return ACTION_ACCEPTENCES.CONTINUE
	var placement: BaseAction = action_interceptor_processor.parent_action
	if placement.get_unit_owner() != status_holder.get_side():
		return ACTION_ACCEPTENCES.CONTINUE
	if action_interceptor_processor.get_shadowed_action_values("lane_index", -1) == status_holder.get_lane_index():
		action_interceptor_processor.set_shadowed_action_values("lane_position", 0)
	return ACTION_ACCEPTENCES.CONTINUE
