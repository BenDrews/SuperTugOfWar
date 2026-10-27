## Placement interceptor (ActionUnitPlacement) for status_effect_lane_rally_point: units on the status's
## side that would be placed in a lane next to this one are placed in this lane instead.
extends BaseActionInterceptor

func process_action_interception(action_interceptor_processor: ActionInterceptorProcessor, _preview_mode: bool = false) -> int:
	var status_holder: StatusEffectHolder = source as StatusEffectHolder
	if status_holder == null:
		return ACTION_ACCEPTENCES.CONTINUE
	var placement: BaseAction = action_interceptor_processor.parent_action
	if placement.get_unit_owner() != status_holder.get_side():
		return ACTION_ACCEPTENCES.CONTINUE
	var lane_index: int = action_interceptor_processor.get_shadowed_action_values("lane_index", -1)
	if abs(lane_index - status_holder.get_lane_index()) == 1:
		action_interceptor_processor.set_shadowed_action_values("lane_index", status_holder.get_lane_index())
	return ACTION_ACCEPTENCES.CONTINUE
