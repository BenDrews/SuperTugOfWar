## Implements basic interface for a status effect's logical component
## See StatusEffect for ui element that uses it
extends RefCounted
class_name BaseStatusEffect

var status_effect_data: StatusEffectData
## The combatant whose side this status belongs to, used as the parent of its actions. For lane and
## unit statuses this is the player, or the frontmost living enemy for enemy-side statuses.
var parent_combatant: BaseCombatant
## What this status is attached to: a combatant, one side of a lane, or a unit. See StatusEffectHolder.
var status_holder: StatusEffectHolder = null

var status_charges: int = 0 : set = set_status_charges
## Typically denotes intensity of the status, or turns left when status_charges is used as a timer
var status_secondary_charges: int = 0
var status_custom_values: Dictionary = {} # any unique values the status uses

func init(_status_effect_data, _parent_combatant: BaseCombatant, _status_holder: StatusEffectHolder = null):
	status_effect_data = _status_effect_data
	parent_combatant = _parent_combatant
	status_holder = _status_holder
	_connect_signals()

## The status's target: the BaseCombatant, UnitLane or Unit it's attached to.
func get_status_target() -> Object:
	if status_holder != null:
		return status_holder.status_target
	return parent_combatant

func get_status_target_type() -> int:
	if status_holder != null:
		return status_holder.status_target_type
	return StatusEffectHolder.STATUS_TARGET_TYPES.COMBATANT

## If this status uses the player's version of its actions (vs the enemy's).
func _is_player_side() -> bool:
	if status_holder != null:
		return status_holder.is_player_side()
	return parent_combatant != null and parent_combatant.is_in_group("players")

## Parent and target combatant for this status's actions. For lane/unit statuses the targets are
## empty: their actions find the lane or unit through the values from _generate_status_effect_card_play_request().
func _get_action_parent() -> BaseCombatant:
	if status_holder != null:
		return status_holder.get_parent_combatant()
	return parent_combatant

func _get_action_targets() -> Array[BaseCombatant]:
	if get_status_target_type() == StatusEffectHolder.STATUS_TARGET_TYPES.COMBATANT:
		return [_get_action_parent()]
	return []

## Override this to provide connections to other signals for statuses with custom events
## NOTE: Do not connect to start and end turn signals, use perform_status_effect_process_actions()
func _connect_signals() -> void:
	pass

## Status action logic performed during turn process times (start/end of turn).
## See: StatusEffectData.status_effect_action_process_times for when this is invoked.
## Called from BaseCombatant.perform_status_effect_process_actions()
func perform_status_effect_process_actions() -> void:
	# get actions to perform
	var action_data: Array[Dictionary] = []
	if _is_player_side():
		action_data = status_effect_data.status_effect_player_process_actions
	else:
		action_data = status_effect_data.status_effect_enemy_process_actions
	
	# perform them
	if len(action_data) > 0:
		var card_play_request: CardPlayRequest = _generate_status_effect_card_play_request() # generate a fake request
		var generated_actions: Array[BaseAction] = ActionGenerator.create_actions(_get_action_parent(), card_play_request, _get_action_targets(), action_data, null)
		ActionHandler.add_actions(generated_actions)

## Performs standard status actions, not tied to turn processes or overflow. This typically
## does not need to be overridden but is invoked conditionally elsewhere, typically through signal listeners.
func perform_status_effect_actions() -> void:
	# get actions to perform
	var action_data: Array[Dictionary] = []
	if _is_player_side():
		action_data = status_effect_data.status_effect_player_actions
	else:
		action_data = status_effect_data.status_effect_enemy_actions
	
	# perform them
	if len(action_data) > 0:
		var card_play_request: CardPlayRequest = _generate_status_effect_card_play_request() # generate a fake request
		var generated_actions: Array[BaseAction] = ActionGenerator.create_actions(_get_action_parent(), card_play_request, _get_action_targets(), action_data, null)
		ActionHandler.add_actions(generated_actions)

## Generates actions for flow actions when status effect charges exceed the status bounds. This will be
## repeated for flow_count times, simulating potentially multiple wraparounds.
func perform_status_effect_flow_actions(flow_count: int = 1) -> void:
	# get actions to perform
	var action_data: Array[Dictionary] = []
	if _is_player_side():
		action_data = status_effect_data.status_effect_player_flow_actions
	else:
		action_data = status_effect_data.status_effect_enemy_flow_actions
	
	# perform them
	if len(action_data) > 0:
		var card_play_request: CardPlayRequest = _generate_status_effect_card_play_request() # generate a fake request
		var generated_actions: Array[BaseAction] = []
		for _i: int in flow_count:
			generated_actions.append_array(ActionGenerator.create_actions(_get_action_parent(), card_play_request, _get_action_targets(), action_data, null))
		ActionHandler.add_actions(generated_actions)

## Factory method to make a fake card play request and pass in status effect related data into it
## Actions can then alias these with the custom_key_names parameter of BaseAction to pass them as parameters
func _generate_status_effect_card_play_request() -> CardPlayRequest:
	var card_play_request: CardPlayRequest = HandManager.create_card_play_request(null, null, false, true)
	card_play_request.card_values = {
		"invoking_status_effect": self, # this is used to get a reference to this status object, if desired. Useful for grabbing status_custom_values
		"invoking_status_effect_object_id": status_effect_data.object_id,
		"invoking_status_effect_charges": status_charges,
		"invoking_status_effect_secondary_charges": status_secondary_charges
	}
	# lane statuses pass their lane as picked_lanes, unit statuses pass status_target_units, so lane
	# actions (BaseLaneAction) act on what the status is attached to
	if status_holder != null and get_status_target_type() != StatusEffectHolder.STATUS_TARGET_TYPES.COMBATANT:
		card_play_request.card_values.merge(status_holder.get_status_target_values())
	return card_play_request

### Status Charges

func add_status_charges(charge_amount: int) -> void:
	status_charges = status_charges + charge_amount

func set_status_charges(value: int):
	# provides setter validation of a status's charge bounds
	var lower_bound: int = status_effect_data.status_effect_charge_lower_bound
	var upper_bound: int = status_effect_data.status_effect_charge_upper_bound
	
	var adjusted_lower_bound: int = 0
	var adjusted_upper_bound: int = upper_bound - lower_bound
	var adjusted_value: int = value - lower_bound
	
	# overflow
	if value > upper_bound and status_effect_data.status_effect_charge_overflows:
		var loop_count: int = floor(float(adjusted_value) / float(adjusted_upper_bound))
		status_charges = lower_bound + value - (adjusted_upper_bound * loop_count)
		perform_status_effect_flow_actions(loop_count)
	# underflow
	elif value < lower_bound and status_effect_data.status_effect_charge_underflows:
		var loop_count: int = floor(float(adjusted_value) / float(adjusted_upper_bound))
		status_charges = upper_bound - value + (adjusted_upper_bound * loop_count)
		perform_status_effect_flow_actions(loop_count)
	else:
	# standard
		status_charges = clamp(value, lower_bound, upper_bound)

## Adds secondary charges, depending on the status_effect_secondary_charge_collision_strategy
func add_status_secondary_charges(charge_amount: int) -> void:
	match status_effect_data.status_effect_secondary_charge_collision_strategy:
		StatusEffectData.STATUS_EFFECT_SECONDARY_CHARGE_COLLISION_STRATEGIES.ADD:
			status_secondary_charges += charge_amount
		StatusEffectData.STATUS_EFFECT_SECONDARY_CHARGE_COLLISION_STRATEGIES.KEEP:
			return # no effect
		StatusEffectData.STATUS_EFFECT_SECONDARY_CHARGE_COLLISION_STRATEGIES.MINIMUM:
			status_secondary_charges = min(status_secondary_charges, charge_amount)
		StatusEffectData.STATUS_EFFECT_SECONDARY_CHARGE_COLLISION_STRATEGIES.MAXIMUM:
			status_secondary_charges = max(status_secondary_charges, charge_amount)
		

## Optional Override
## Certain statuses will reserve chunks of the healthbar visually.
## Use this to get how much that is for each status that inflicts damage
## Typically just returns 0, status_charges or status_secondary_charges, but may have conditional logic
func get_status_healthbar_reserved_amount() -> int:
	match status_effect_data.status_effect_healthbar_reserve_type:
		StatusEffectData.STATUS_EFFECT_HEALTHBAR_RESERVE_TYPES.ZERO:
			return 0
		StatusEffectData.STATUS_EFFECT_HEALTHBAR_RESERVE_TYPES.STATUS_CHARGES:
			return status_charges
		StatusEffectData.STATUS_EFFECT_HEALTHBAR_RESERVE_TYPES.STATUS_SECONDARY_CHARGES:
			return status_secondary_charges
	return 0

## Optional Override
## Tells BaseCombatant how much to decay the status after this status has been invoked.
## You may wish to override to supply conditional decay logic.
## NOTE: In the case of statuses that allow duplicates it is strongly advised to only use linear
## decay rates with non conditional decay as the first status determines the decay rate for the others
## which may produce unintended results.
func get_status_decay_amount() -> int:
	# figure out how much to decay by and generate an instant interceptable action to decay by that amount
	var decay_amount: int = status_effect_data.status_effect_decay_rate # defaults to linear decay
	# non linear decay
	match status_effect_data.status_effect_decay_type:
		StatusEffectData.STATUS_EFFECT_DECAY_TYPES.ZERO_OUT:
			decay_amount = -1 * status_charges
		StatusEffectData.STATUS_EFFECT_DECAY_TYPES.HALF_LIFE_ROUND_UP:
			decay_amount = -1 * int(floor(float(status_charges) * 0.5)) # since the value is subtracted, floor() means rounding up
		StatusEffectData.STATUS_EFFECT_DECAY_TYPES.HALF_LIFE_ROUND_DOWN:
			decay_amount = -1 * int(ceil(float(status_charges) * 0.5)) # since the value is subtracted, ceil() means rounding down
			
	return decay_amount
