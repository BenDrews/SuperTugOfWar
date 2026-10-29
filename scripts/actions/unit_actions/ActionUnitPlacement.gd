## Interceptor hook for where a unit is placed. ActionSummonUnit creates one of these just before
## placing a unit and intercepts it (it is never performed, like ActionCardPlay), so statuses and
## artifacts can redirect the unit before it lands.
##
## Shadow these values in an interceptor to change the placement:
## - lane_index: int. The lane the unit goes in (clamped to valid lanes afterwards).
## - lane_position: int. Index in its side of the lane, 0 = front, -1 = back of the line.
## Return REJECTED to stop the unit being placed at all (a player's card then goes to the discard pile
## at the end of the turn).
## Read-only context for interceptors: unit_owner (Unit.UNIT_OWNERS), requested_lane_index,
## requested_lane_position, unit_name, unit_strength, unit_stamina.
##
## Who can intercept:
## - the placer's combatant (parent interceptors), eg an artifact
## - statuses on EVERY lane, both sides (status context holders), so a status in one lane can pull units
##   in from another. Interceptors should check (source as StatusEffectHolder) lane/side against the
##   placement. Use interceptor priority to order lane changes (higher) before position changes.
## After placement is settled, ActionSummonUnit's own interception (stats) uses the final lane.
extends BaseAction

func perform_action() -> void:
	pass # only intercepted, never performed

func get_unit_owner() -> int:
	return get_action_value("unit_owner", Unit.UNIT_OWNERS.PLAYER)

func get_status_context_holders() -> Array[Object]:
	var holders: Array[Object] = []
	for lane: UnitLane in Battlefield.get_lanes():
		holders.append(lane.player_status_holder)
		holders.append(lane.enemy_status_holder)
	return holders

func is_instant_action() -> bool:
	return true

func _to_string() -> String:
	return "Unit Placement Action: lane %s position %s" % [get_action_value("lane_index", -1), get_action_value("lane_position", -1)]
