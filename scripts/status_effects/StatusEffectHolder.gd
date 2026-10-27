## Holds and manages the status effects on one status target. A status target can be:
## - a combatant (the player or an enemy; see BaseCombatant, which delegates to its holder)
## - one side of a lane (see UnitLane; each lane has a player-side and an enemy-side holder)
## - a unit (see Unit)
## Moved out of BaseCombatant so all three share the same status logic: charges, stacking,
## decay, UI icons, process actions and interceptor registration.
##
## Interceptors from a status are registered under get_interceptor_key(): the combatant itself for
## combatants (so existing interceptors keep working), or this holder for lanes and units. Actions
## pick up lane/unit interceptors through BaseAction.get_status_context_holders().
extends RefCounted
class_name StatusEffectHolder

enum STATUS_TARGET_TYPES {COMBATANT, LANE, UNIT}

## What kind of thing holds these statuses.
var status_target_type: int = STATUS_TARGET_TYPES.COMBATANT
## The BaseCombatant, UnitLane or Unit holding the statuses.
var status_target: Object = null
## Which side these statuses belong to (Unit.UNIT_OWNERS). Decides whether the status data's player
## or enemy actions are used, and when the statuses are processed.
var side: int = Unit.UNIT_OWNERS.PLAYER
## Lane index for lane and unit holders, -1 for combatants.
var lane_index: int = -1
## Where StatusEffect icons are shown. Can be null for invisible holders.
var status_container: Control = null

## Maps status id to the array of StatusEffect ui element(s) for it.
var status_id_to_status_effects: Dictionary = {}

func _init(_status_target_type: int, _status_target: Object, _side: int, _status_container: Control, _lane_index: int = -1) -> void:
	status_target_type = _status_target_type
	status_target = _status_target
	side = _side
	status_container = _status_container
	lane_index = _lane_index

#region Identity
func is_player_side() -> bool:
	return get_side() == Unit.UNIT_OWNERS.PLAYER

func get_side() -> int:
	if status_target_type == STATUS_TARGET_TYPES.COMBATANT and is_instance_valid(status_target):
		return Unit.UNIT_OWNERS.PLAYER if status_target.is_in_group("players") else Unit.UNIT_OWNERS.ENEMY
	return side

## Object interceptors from these statuses are registered under.
func get_interceptor_key() -> Object:
	if status_target_type == STATUS_TARGET_TYPES.COMBATANT:
		return status_target
	return self

## The combatant that "owns" these statuses, used as the parent of their actions:
## the combatant itself, or for lanes/units the player or the frontmost living enemy.
func get_parent_combatant() -> BaseCombatant:
	if status_target_type == STATUS_TARGET_TYPES.COMBATANT:
		return status_target
	if is_player_side():
		return Global.get_player()
	var enemies: Array[Enemy] = Global.get_alive_enemies()
	return enemies[0] if len(enemies) > 0 else null

## Values injected into status actions so they know what they're attached to. Lane holders pass
## picked_lanes (so lane actions act on that lane) and unit holders pass status_target_units.
func get_status_target_values() -> Dictionary:
	var target_values: Dictionary = {"status_target_type": status_target_type, "status_target_side": get_side()}
	match status_target_type:
		STATUS_TARGET_TYPES.LANE:
			target_values["picked_lanes"] = [lane_index]
			target_values["unit_owner_filter"] = get_side()
		STATUS_TARGET_TYPES.UNIT:
			target_values["picked_lanes"] = [lane_index]
			target_values["status_target_units"] = [status_target]
	return target_values
#endregion

#region Charges
## Adds charges and secondary charges to ALL instances of a given status.
## If no status exists, create one and apply charges. Removes statuses that become zero'd out.
func add_status_effect_charges(status_effect_object_id: String, charge_amount: int, secondary_charge_amount: int = 0) -> void:
	var status_effect_data: StatusEffectData = Global.get_status_effect_data(status_effect_object_id)
	if status_effect_data == null:
		DebugLogger.log_error("Status effect {0} does not exist".format([status_effect_object_id]))
		return

	var status_effects: Array[StatusEffect] = []
	if status_id_to_status_effects.has(status_effect_object_id):
		status_effects = status_id_to_status_effects[status_effect_object_id]

	# create a new status if none exists
	if len(status_effects) == 0:
		var _status_effect: StatusEffect = _create_status_effect(status_effect_object_id)
		status_effects = status_id_to_status_effects[status_effect_object_id]
		var status_effect_secondary_charge_collision_strategy: int = _status_effect.status_effect_script.status_effect_data.status_effect_secondary_charge_collision_strategy
		if status_effect_secondary_charge_collision_strategy == StatusEffectData.STATUS_EFFECT_SECONDARY_CHARGE_COLLISION_STRATEGIES.KEEP:
			_status_effect.status_effect_script.status_secondary_charges = secondary_charge_amount

	for status_effect in status_effects.duplicate():
		var status_effect_script: BaseStatusEffect = status_effect.status_effect_script
		status_effect_script.add_status_charges(charge_amount)
		status_effect_script.add_status_secondary_charges(secondary_charge_amount)
		if status_effect_script.status_charges == 0:
			_remove_status_effect(status_effect)
		else:
			status_effect.update_status_charge_display()

	_on_statuses_changed()

## Adds an entirely new status effect with given charges. Mainly useful for statuses that allow
## multiples; fails if the status doesn't allow multiples and one already exists.
func add_new_status_effect(status_effect_object_id: String, charge_amount: int, secondary_charge_amount: int = 0, custom_values: Dictionary = {}) -> void:
	var status_effect_data: StatusEffectData = Global.get_status_effect_data(status_effect_object_id)
	if status_effect_data == null:
		DebugLogger.log_error("Status effect {0} does not exist".format([status_effect_object_id]))
		return
	var status_effect: StatusEffect = _create_status_effect(status_effect_object_id)
	if status_effect != null:
		var status_effect_script: BaseStatusEffect = status_effect.status_effect_script
		status_effect_script.add_status_charges(charge_amount)
		status_effect_script.status_secondary_charges += secondary_charge_amount
		status_effect_script.status_custom_values = custom_values
		if status_effect_script.status_charges == 0:
			_remove_status_effect(status_effect)
		else:
			status_effect.update_status_charge_display()
	_on_statuses_changed()

func clear_all_status_effects() -> void:
	for status_effect_object_id in status_id_to_status_effects.keys().duplicate():
		var status_effects: Array[StatusEffect] = status_id_to_status_effects[status_effect_object_id]
		for status_effect in status_effects.duplicate():
			_remove_status_effect(status_effect)
	status_id_to_status_effects.clear()
	_on_statuses_changed()

## Returns the charges of a status, zero if not applied. If multiple, returns the absolute maximum.
func get_status_charges(status_effect_object_id: String) -> int:
	var absolute_maximum: int = 0
	for status_effect: StatusEffect in status_id_to_status_effects.get(status_effect_object_id, []):
		if abs(status_effect.status_effect_script.status_charges) > abs(absolute_maximum):
			absolute_maximum = status_effect.status_effect_script.status_charges
	return absolute_maximum

## Returns the secondary charges of a status, zero if not applied. If multiple, uses the one with the most charges.
func get_status_secondary_charges(status_effect_object_id: String) -> int:
	var absolute_maximum: int = 0
	for status_effect: StatusEffect in status_id_to_status_effects.get(status_effect_object_id, []):
		if abs(status_effect.status_effect_script.status_charges) > abs(absolute_maximum):
			absolute_maximum = status_effect.status_effect_script.status_secondary_charges
	return absolute_maximum

func has_status_effects() -> bool:
	return len(status_id_to_status_effects) > 0
#endregion

#region Decay
## Decrements statuses by the decay rate and potentially removes them.
func _decay_status_effect(status_effect_object_id: String) -> void:
	var status_effects: Array[StatusEffect] = []
	if status_id_to_status_effects.has(status_effect_object_id):
		status_effects = status_id_to_status_effects[status_effect_object_id]
	if len(status_effects) > 0:
		var decay_amount: int = status_effects[0].status_effect_script.get_status_decay_amount()
		ActionGenerator.generate_decay_status_effect(self, status_effect_object_id, decay_amount)

func _decay_all_status_effects() -> void:
	for status_effect_object_id in status_id_to_status_effects.keys().duplicate():
		_decay_status_effect(status_effect_object_id)
#endregion

#region Processing
## Processes and then decays all status effects belonging to a given process time (turn phase).
func perform_status_effect_process_actions(status_effect_process_time: int) -> void:
	var status_effect_ids: Array[String] = _get_status_effects_with_process_time(status_id_to_status_effects.keys(), status_effect_process_time)
	status_effect_ids.sort_custom(_sort_status_effect_priorities)
	for status_effect_object_id in status_effect_ids:
		if not status_id_to_status_effects.has(status_effect_object_id):
			continue # removed by an earlier status this phase
		var status_effects: Array[StatusEffect] = status_id_to_status_effects[status_effect_object_id]
		for status_effect in status_effects:
			status_effect.status_effect_script.perform_status_effect_process_actions()
		_decay_status_effect(status_effect_object_id)

func _get_status_effects_with_process_time(status_effect_object_ids: Array, status_effect_process_time: int) -> Array[String]:
	var returned_status_effect_ids: Array[String] = []
	for status_effect_object_id: String in status_effect_object_ids:
		var status_effect_data: StatusEffectData = Global.get_status_effect_data(status_effect_object_id)
		if status_effect_data == null:
			continue
		if not status_effect_data.status_effect_action_process_times.has(status_effect_process_time):
			continue
		returned_status_effect_ids.append(status_effect_object_id)
	return returned_status_effect_ids

## Higher priority first; ties broken by id so the order is always consistent.
func _sort_status_effect_priorities(status_effect_object_id_1: String, status_effect_object_id_2: String) -> bool:
	var status_effect_data_1: StatusEffectData = Global.get_status_effect_data(status_effect_object_id_1)
	var status_effect_data_2: StatusEffectData = Global.get_status_effect_data(status_effect_object_id_2)
	if status_effect_data_1.status_effect_priority == status_effect_data_2.status_effect_priority:
		return status_effect_data_1.object_id > status_effect_data_2.object_id
	return status_effect_data_1.status_effect_priority > status_effect_data_2.status_effect_priority
#endregion

#region Creation
func _remove_status_effect(status_effect: StatusEffect) -> void:
	var status_effect_data: StatusEffectData = status_effect.status_effect_script.status_effect_data
	var status_effect_object_id: String = status_effect_data.object_id
	var status_effects: Array[StatusEffect] = status_id_to_status_effects[status_effect_object_id]
	status_effects.erase(status_effect)
	if len(status_effects) == 0:
		status_id_to_status_effects.erase(status_effect_object_id)
		for interceptor_id in status_effect_data.status_effect_interceptor_ids:
			ActionHandler.unregister_action_interceptor(get_interceptor_key(), interceptor_id)
	status_effect.queue_free()

## Creates a status and its bindings. Does not allow duplicates of statuses that don't allow multiples.
func _create_status_effect(status_effect_object_id: String) -> StatusEffect:
	var status_effect_data: StatusEffectData = Global.get_status_effect_data(status_effect_object_id)
	var status_exists: bool = len(status_id_to_status_effects.get(status_effect_object_id, [])) > 0
	if status_exists and not status_effect_data.status_effect_allows_multiples:
		return null

	var status_effect: StatusEffect = Scenes.STATUS_EFFECT.instantiate()
	var status_effect_script: BaseStatusEffect = load(status_effect_data.status_effect_script_path).new()
	if status_id_to_status_effects.has(status_effect_object_id):
		status_id_to_status_effects[status_effect_object_id].append(status_effect)
	else:
		var statuses: Array[StatusEffect] = [status_effect]
		status_id_to_status_effects[status_effect_object_id] = statuses

	status_effect.status_effect_script = status_effect_script
	if status_container != null:
		status_container.add_child(status_effect)
	status_effect_script.init(status_effect_data, get_parent_combatant(), self)

	# register interceptors when creating the first instance of an effect
	if not status_exists:
		for interceptor_id in status_effect_data.status_effect_interceptor_ids:
			ActionHandler.register_action_interceptor(get_interceptor_key(), interceptor_id)
	return status_effect

func _on_statuses_changed() -> void:
	Signals.enemy_intent_changed.emit() # update enemy intent in case statuses affect them
	if status_target_type != STATUS_TARGET_TYPES.COMBATANT:
		Signals.status_target_statuses_changed.emit(self)
#endregion
