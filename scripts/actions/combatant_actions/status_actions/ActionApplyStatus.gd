## Applies status effect charges to a status target. Values:
## - status_effect_object_id: String
## - status_charge_amount / status_secondary_charge_amount: int
## - status_force_apply_new_effect: bool. Add a separate new instance instead of adding charges.
## - status_target_type: int (StatusEffectHolder.STATUS_TARGET_TYPES). What the status goes on:
##   - COMBATANT (default): the action's targets, as before.
##   - LANE: one side of each picked lane (from a parent ActionPickLanes, or picked_lanes).
##     status_lane_side (Unit.UNIT_OWNERS) picks the side; defaults to the side of whoever applies it.
##   - UNIT: every unit in the picked lanes passing unit_owner_filter (default: the applier's side),
##     or the units in status_target_units.
extends BaseAction

func perform_action():
	var status_target_type: int = get_action_value("status_target_type", StatusEffectHolder.STATUS_TARGET_TYPES.COMBATANT)
	if status_target_type != StatusEffectHolder.STATUS_TARGET_TYPES.COMBATANT:
		_apply_to_status_holders(get_target_status_holders())
		return
	
	var action_interceptor_processors: Array[ActionInterceptorProcessor] = _intercept_action()
	
	for action_interceptor_processor in action_interceptor_processors:
		var target: BaseCombatant = action_interceptor_processor.target
		if target == null:
			return
		_apply_to_holder(target.get_status_holder(), action_interceptor_processor)

## The lane-side or unit holders this action applies to (empty for combatant targets).
func get_target_status_holders() -> Array[StatusEffectHolder]:
	var holders: Array[StatusEffectHolder] = []
	var status_target_type: int = get_action_value("status_target_type", StatusEffectHolder.STATUS_TARGET_TYPES.COMBATANT)
	var applier_side: int = Unit.UNIT_OWNERS.ENEMY if parent_combatant is Enemy else Unit.UNIT_OWNERS.PLAYER
	match status_target_type:
		StatusEffectHolder.STATUS_TARGET_TYPES.LANE:
			var lane_side: int = get_action_value("status_lane_side", applier_side)
			for lane_index: int in BaseLaneAction.get_picked_lanes_for(self):
				var lane: UnitLane = Battlefield.get_lane(lane_index)
				if lane != null:
					holders.append(lane.get_status_holder(lane_side))
		StatusEffectHolder.STATUS_TARGET_TYPES.UNIT:
			var unit_owner_filter: int = get_action_value("unit_owner_filter", applier_side)
			for unit: Unit in BaseLaneAction.get_affected_units_for(self, unit_owner_filter):
				holders.append(unit.get_status_holder())
	return holders

func _apply_to_status_holders(holders: Array[StatusEffectHolder]) -> void:
	for action_interceptor_processor in _intercept_action([]):
		for status_holder: StatusEffectHolder in holders:
			_apply_to_holder(status_holder, action_interceptor_processor)

func _apply_to_holder(status_holder: StatusEffectHolder, action_interceptor_processor: ActionInterceptorProcessor) -> void:
	var status_charge_amount: int = action_interceptor_processor.get_shadowed_action_values("status_charge_amount", 1)
	var status_secondary_charge_amount: int = action_interceptor_processor.get_shadowed_action_values("status_secondary_charge_amount", 0)
	var status_effect_object_id: String = action_interceptor_processor.get_shadowed_action_values("status_effect_object_id", "")
	var status_force_apply_new_effect: int = action_interceptor_processor.get_shadowed_action_values("status_force_apply_new_effect", false)
	# determine whether to apply charges or to force the application of an entirely new status effect
	if status_force_apply_new_effect:
		status_holder.add_new_status_effect(status_effect_object_id, status_charge_amount, status_secondary_charge_amount)
	else:
		status_holder.add_status_effect_charges(status_effect_object_id, status_charge_amount, status_secondary_charge_amount)

## Interceptors on the lane/unit holders receiving the status apply too.
func get_status_context_holders() -> Array[Object]:
	var holders: Array[Object] = []
	holders.assign(get_target_status_holders())
	return holders

func is_action_short_circuited() -> bool:
	return get_action_value("action_short_circuits", true)

func _to_string():
	var status_charge_amount: int = get_action_value("status_charge_amount", 0)
	var status_effect_object_id: String = get_action_value("status_effect_object_id", "")
	return "Apply Status Action: " + status_effect_object_id + " " + str(status_charge_amount)
