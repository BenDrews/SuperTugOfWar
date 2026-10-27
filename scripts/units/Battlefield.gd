## The tug of war battlefield: LANE_COUNT lanes stacked vertically between the player and the enemies.
## Created by Combat in code. Spawns units into lanes on Signals.unit_spawn_requested, runs lane
## picks requested by ActionBasePickLanes, shows each enemy's per-lane intents at the right end of
## the lanes, and clears everything when combat or the run ends.
## Static helpers let actions query lanes and units without a node reference.
extends Control
class_name Battlefield

const LANE_COUNT: int = 3
const LANE_SEPARATION: int = 10
const PICK_PROMPT_HEIGHT: float = 40.0

## The live battlefield. Set in _ready().
static var instance: Battlefield = null

var lanes: Array[UnitLane] = []

## The lane pick in progress, if any.
var _current_lane_pick: ActionBasePickLanes = null
var _pick_prompt_label: Label = null
var _intent_refresh_queued: bool = false

func _ready() -> void:
	instance = self
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var lane_box: VBoxContainer = VBoxContainer.new()
	lane_box.name = "Lanes"
	lane_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lane_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lane_box.add_theme_constant_override("separation", LANE_SEPARATION)
	add_child(lane_box)

	for lane_index: int in LANE_COUNT:
		var lane: UnitLane = UnitLane.new()
		lane.size_flags_vertical = Control.SIZE_EXPAND_FILL
		lane.init(lane_index)
		lane.lane_clicked.connect(_on_lane_clicked)
		lane_box.add_child(lane)
		lanes.append(lane)

	# prompt shown under the lanes while picking
	_pick_prompt_label = Label.new()
	_pick_prompt_label.name = "LanePickPrompt"
	_pick_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pick_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pick_prompt_label.add_theme_font_size_override("font_size", 24)
	_pick_prompt_label.add_theme_color_override("font_color", UnitLane.INSERT_MARKER_COLOR)
	_pick_prompt_label.visible = false
	add_child(_pick_prompt_label)
	resized.connect(_on_resized)
	_on_resized()

	# played unit cards fly here instead of to the discard pile
	HandManager.card_destination_to_ui_elements[HandManager.UNIT_FIELD_PILE] = self

	Signals.unit_spawn_requested.connect(_on_unit_spawn_requested)
	Signals.unit_discarded.connect(_on_unit_changed)
	Signals.unit_stamina_changed.connect(_on_unit_changed)
	Signals.unit_strength_changed.connect(_on_unit_changed)
	Signals.tug_of_war_resolved.connect(_on_tug_of_war_resolved)
	Signals.lane_pick_requested.connect(_on_lane_pick_requested)
	Signals.enemy_intent_changed.connect(queue_intent_refresh)
	Signals.enemy_killed.connect(func(_enemy: Enemy): queue_intent_refresh())
	Signals.enemy_lane_intent_performed.connect(_on_enemy_lane_intent_performed)
	Signals.combat_started.connect(_on_combat_started)
	Signals.combat_ended.connect(_on_combat_ended)
	Signals.run_ended.connect(_on_run_ended)

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _on_resized() -> void:
	_pick_prompt_label.position = Vector2(0, size.y + 4)
	_pick_prompt_label.size = Vector2(size.x, PICK_PROMPT_HEIGHT)

#region Units
## Spawns a unit into a lane. lane_index is clamped to valid lanes; lane_position is the index
## within its owner's side (0 = front, -1 = back of the line).
func spawn_unit(card_data: CardData, unit_name: String, unit_strength: int, unit_stamina: int,
unit_owner: int = Unit.UNIT_OWNERS.PLAYER, lane_index: int = 0, lane_position: int = -1) -> Unit:
	var unit: Unit = Unit.new()
	unit.init(card_data, unit_name, unit_strength, unit_stamina, unit_owner)
	var lane: UnitLane = lanes[clamp(lane_index, 0, LANE_COUNT - 1)]
	lane.add_unit(unit, lane_position)
	Signals.unit_spawned.emit(unit)
	return unit

## Removes all units without moving their cards. The combat deck is rebuilt from the
## player's deck at the start of each combat, so field cards don't need returning.
func clear_units() -> void:
	for lane: UnitLane in lanes:
		lane.clear_units()

## Removes all lane statuses (lane powers only last for the combat they were played in).
func clear_lane_status_effects() -> void:
	for lane: UnitLane in lanes:
		lane.clear_status_effects()
#endregion

#region Enemy Intents
## Rebuilds the lane intent displays at the end of this frame (batches multiple change signals).
func queue_intent_refresh() -> void:
	if _intent_refresh_queued:
		return
	_intent_refresh_queued = true
	refresh_lane_intents.call_deferred()

## Shows every living enemy's current intent for each lane in that lane's intent slot.
func refresh_lane_intents() -> void:
	_intent_refresh_queued = false
	for lane: UnitLane in lanes:
		var displays: Array[LaneIntentDisplay] = []
		for enemy: Enemy in Global.get_alive_enemies():
			var lane_intent: EnemyIntentData = enemy.enemy_data.get_current_lane_intent(lane.lane_index)
			if lane_intent == null:
				continue
			var display: LaneIntentDisplay = LaneIntentDisplay.new()
			display.init(enemy, lane_intent, lane.lane_index)
			displays.append(display)
		lane.set_lane_intents(displays)

func _clear_lane_intents() -> void:
	for lane: UnitLane in lanes:
		lane.set_lane_intents([])

func _on_enemy_lane_intent_performed(enemy: Enemy, lane_index: int) -> void:
	var lane: UnitLane = get_lane(lane_index)
	if lane == null:
		return
	for display: LaneIntentDisplay in lane.get_lane_intents():
		if display.enemy == enemy:
			display.flash()
#endregion

#region Status Resolution
## Status holders of one side in resolution order:
## 1) the side's combatants (the player, or each living enemy)
## 2) the side's half of each lane, top to bottom
## 3) the side's units: lanes top to bottom, and within a lane front (inside, nearest the rope) to back (outside)
static func get_side_status_holders(side: int, include_combatants: bool = true, include_field: bool = true) -> Array[StatusEffectHolder]:
	var holders: Array[StatusEffectHolder] = []
	if include_combatants:
		if side == Unit.UNIT_OWNERS.PLAYER:
			var player: Player = Global.get_player()
			if player != null:
				holders.append(player.get_status_holder())
		else:
			for enemy: Enemy in Global.get_alive_enemies():
				holders.append(enemy.get_status_holder())
	if include_field:
		for lane: UnitLane in get_lanes():
			holders.append(lane.get_status_holder(side))
		for lane: UnitLane in get_lanes():
			for unit: Unit in lane.get_side_units(side): # front to back
				if unit.get_status_holder() != null:
					holders.append(unit.get_status_holder())
	return holders

## Processes one side's status effects for a process time, in the order of get_side_status_holders(),
## waiting for each holder's actions to finish before the next so the order is exact.
## Combat calls this with the player's process times for PLAYER and the enemy times for ENEMY.
func process_side_status_effects(side: int, status_effect_process_time: int, include_combatants: bool = true, include_field: bool = true) -> void:
	for status_holder: StatusEffectHolder in get_side_status_holders(side, include_combatants, include_field):
		if status_holder.status_target_type == StatusEffectHolder.STATUS_TARGET_TYPES.UNIT and status_holder.status_target.is_discarded:
			continue # left the field earlier in this pass
		status_holder.perform_status_effect_process_actions(status_effect_process_time)
		if ActionHandler.actions_being_performed:
			await ActionHandler.actions_ended
#endregion

#region Static Helpers
## Returns a lane by index, or null if there's no battlefield or the index is invalid.
static func get_lane(lane_index: int) -> UnitLane:
	if instance == null or lane_index < 0 or lane_index >= len(instance.lanes):
		return null
	return instance.lanes[lane_index]

static func get_lanes() -> Array[UnitLane]:
	if instance == null:
		return []
	return instance.lanes.duplicate()

## Returns live units, in lane order then front to back. Pass a Unit.UNIT_OWNERS value to only get
## one side's units, and/or a lane index to only get one lane's units.
static func get_units(unit_owner: int = Unit.UNIT_OWNER_AUTOMATIC, lane_index: int = -1) -> Array[Unit]:
	var units: Array[Unit] = []
	for lane: UnitLane in get_lanes():
		if lane_index == -1 or lane.lane_index == lane_index:
			units += lane.get_units(unit_owner)
	return units

## Total strength of live units for one side (or both), in one lane (or all lanes).
static func get_total_strength(unit_owner: int = Unit.UNIT_OWNER_AUTOMATIC, lane_index: int = -1) -> int:
	var total: int = 0
	for unit: Unit in get_units(unit_owner, lane_index):
		total += unit.unit_strength
	return total

## Returns if any live unit was summoned by the given card.
static func is_card_on_field(card_data: CardData) -> bool:
	for unit: Unit in get_units():
		if unit.card_data == card_data:
			return true
	return false

## Moves any card in the field pile that no longer has a live unit to the discard pile.
## Covers edge cases like a summon being rejected by an interceptor or a placement being cancelled.
static func release_orphaned_field_cards() -> void:
	for card_data: CardData in HandManager.get_pile(HandManager.UNIT_FIELD_PILE):
		if not is_card_on_field(card_data):
			HandManager.move_card_to_pile(card_data, HandManager.UNIT_FIELD_PILE, HandManager.DISCARD_PILE, HandManager.PILE_INSERTION_STRATEGIES.TOP, HandManager.PLAYER_DEFAULT_HAND_CARD_COUNT_MAX, true, true)
#endregion

#region Lane Picking
func is_picking_lane() -> bool:
	return _current_lane_pick != null

func _on_lane_pick_requested(lane_pick_action: ActionBasePickLanes) -> void:
	_current_lane_pick = lane_pick_action
	_refresh_pickable_lanes()
	_pick_prompt_label.text = lane_pick_action.get_lane_pick_text()
	_pick_prompt_label.visible = true

func _refresh_pickable_lanes() -> void:
	var pickable_lane_indexes: Array[int] = _current_lane_pick.get_pickable_lanes()
	var picks_position: bool = _current_lane_pick.is_position_pick()
	for lane: UnitLane in lanes:
		var pickable: bool = pickable_lane_indexes.has(lane.lane_index) and not _current_lane_pick.picked_lanes.has(lane.lane_index)
		lane.set_pickable(pickable, picks_position)

func _on_lane_clicked(lane: UnitLane, lane_position: int) -> void:
	if _current_lane_pick == null or not lane.is_pickable:
		return
	_current_lane_pick.picked_lanes.append(lane.lane_index)
	_current_lane_pick.picked_lane_position = lane_position
	if len(_current_lane_pick.picked_lanes) >= _current_lane_pick.get_lane_pick_count():
		_end_lane_pick()
		Signals.lane_pick_confirmed.emit()
	else:
		_refresh_pickable_lanes() # multi-lane pick: keep going

func _end_lane_pick() -> void:
	_current_lane_pick = null
	_pick_prompt_label.visible = false
	for lane: UnitLane in lanes:
		lane.set_pickable(false)
#endregion

#region Signals
func _on_unit_spawn_requested(card_data: CardData, unit_name: String, unit_strength: int, unit_stamina: int, unit_owner: int, lane_index: int, lane_position: int) -> void:
	spawn_unit(card_data, unit_name, unit_strength, unit_stamina, unit_owner, lane_index, lane_position)

func _on_unit_changed(unit: Unit) -> void:
	if unit.lane != null:
		unit.lane.update_tally()

func _on_tug_of_war_resolved(lane_index: int, _player_strength: int, _enemy_strength: int) -> void:
	var lane: UnitLane = get_lane(lane_index)
	if lane != null:
		lane.flash_tally()

func _on_combat_started(_event_id: String) -> void:
	_end_lane_pick()
	clear_units()
	clear_lane_status_effects()

func _on_combat_ended() -> void:
	_end_lane_pick()
	clear_units()
	clear_lane_status_effects()
	_clear_lane_intents()

func _on_run_ended() -> void:
	_end_lane_pick()
	clear_units()
	clear_lane_status_effects()
	_clear_lane_intents()
#endregion
