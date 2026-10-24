## Holds and lays out the Units on the battlefield. Created by Combat in code.
## Player units line up on the left, enemy units on the right, with a live strength readout
## in the middle. Spawns units on Signals.unit_spawn_requested and clears them when combat or the run ends.
## Also provides static helpers for querying units from actions.
## NOTE: Lanes will slot in here later: one row per lane, with spawn requests carrying a lane index.
extends Control
class_name UnitContainer

const UNIT_SEPARATION: int = 8
const TALLY_WIDTH: float = 150.0
const TALLY_FLASH_TIME: float = 0.6
const TALLY_PLAYER_WINNING_COLOR: Color = Color(0.55, 0.9, 0.55)
const TALLY_ENEMY_WINNING_COLOR: Color = Color(1.0, 0.5, 0.45)

var _player_unit_flow: HFlowContainer = null
var _enemy_unit_flow: HFlowContainer = null
var _tally_label: Label = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var row: HBoxContainer = HBoxContainer.new()
	row.name = "UnitRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", UNIT_SEPARATION)
	add_child(row)

	_player_unit_flow = _make_unit_flow("PlayerUnitFlow", FlowContainer.ALIGNMENT_END) # player units bunch toward the middle
	row.add_child(_player_unit_flow)

	_tally_label = Label.new()
	_tally_label.name = "StrengthTally"
	_tally_label.custom_minimum_size = Vector2(TALLY_WIDTH, 0)
	_tally_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tally_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tally_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tally_label.add_theme_font_size_override("font_size", 20)
	row.add_child(_tally_label)

	_enemy_unit_flow = _make_unit_flow("EnemyUnitFlow", FlowContainer.ALIGNMENT_BEGIN) # enemy units bunch toward the middle
	row.add_child(_enemy_unit_flow)

	# played unit cards fly here instead of to the discard pile
	HandManager.card_destination_to_ui_elements[HandManager.UNIT_FIELD_PILE] = _player_unit_flow

	Signals.unit_spawn_requested.connect(_on_unit_spawn_requested)
	Signals.unit_discarded.connect(_on_unit_changed)
	Signals.unit_stamina_changed.connect(_on_unit_changed)
	Signals.tug_of_war_resolved.connect(_on_tug_of_war_resolved)
	Signals.combat_started.connect(_on_combat_started)
	Signals.combat_ended.connect(_on_combat_ended)
	Signals.run_ended.connect(_on_run_ended)

	update_tally()

func _make_unit_flow(flow_name: String, alignment: int) -> HFlowContainer:
	var flow: HFlowContainer = HFlowContainer.new()
	flow.name = flow_name
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.alignment = alignment
	flow.add_theme_constant_override("h_separation", UNIT_SEPARATION)
	flow.add_theme_constant_override("v_separation", UNIT_SEPARATION)
	return flow

func spawn_unit(card_data: CardData, unit_name: String, unit_strength: int, unit_stamina: int, unit_owner: int = Unit.UNIT_OWNERS.PLAYER) -> Unit:
	var unit: Unit = Unit.new()
	if unit_owner == Unit.UNIT_OWNERS.ENEMY:
		_enemy_unit_flow.add_child(unit)
	else:
		_player_unit_flow.add_child(unit)
	unit.init(card_data, unit_name, unit_strength, unit_stamina, unit_owner)
	Signals.unit_spawned.emit(unit)
	update_tally()
	return unit

## Removes all units without moving their cards. The combat deck is rebuilt from the
## player's deck at the start of each combat, so field cards don't need returning.
func clear_units() -> void:
	for flow: HFlowContainer in [_player_unit_flow, _enemy_unit_flow]:
		for child: Node in flow.get_children():
			if child is Unit:
				child.clear_unit()
			else:
				child.queue_free()
	update_tally()

## Updates the "You X vs Y Enemy" readout. Hidden when nothing is on the field.
func update_tally() -> void:
	var player_strength: int = get_total_strength(Unit.UNIT_OWNERS.PLAYER)
	var enemy_strength: int = get_total_strength(Unit.UNIT_OWNERS.ENEMY)
	_tally_label.visible = len(get_units()) > 0
	_tally_label.text = "You  %d\nvs\n%d  Enemy" % [player_strength, enemy_strength]
	if player_strength > enemy_strength:
		_tally_label.modulate = TALLY_PLAYER_WINNING_COLOR
	elif enemy_strength > player_strength:
		_tally_label.modulate = TALLY_ENEMY_WINNING_COLOR
	else:
		_tally_label.modulate = Color.WHITE

#region Static Helpers
## Returns all live units on the battlefield, in summon order.
## Pass a Unit.UNIT_OWNERS value to only get one side's units.
static func get_units(unit_owner: int = Unit.UNIT_OWNER_AUTOMATIC) -> Array[Unit]:
	var units: Array[Unit] = []
	for unit: Unit in Global.get_tree().get_nodes_in_group(Unit.UNITS_GROUP):
		if unit_owner == Unit.UNIT_OWNER_AUTOMATIC or unit.unit_owner == unit_owner:
			units.append(unit)
	return units

## Total strength of all live units on one side (or both sides if no owner given).
static func get_total_strength(unit_owner: int = Unit.UNIT_OWNER_AUTOMATIC) -> int:
	var total: int = 0
	for unit: Unit in get_units(unit_owner):
		total += unit.unit_strength
	return total

## Returns if any live unit was summoned by the given card.
static func is_card_on_field(card_data: CardData) -> bool:
	for unit: Unit in get_units():
		if unit.card_data == card_data:
			return true
	return false

## Moves any card in the field pile that no longer has a live unit to the discard pile.
## Covers edge cases like a summon being rejected by an interceptor.
static func release_orphaned_field_cards() -> void:
	for card_data: CardData in HandManager.get_pile(HandManager.UNIT_FIELD_PILE):
		if not is_card_on_field(card_data):
			HandManager.move_card_to_pile(card_data, HandManager.UNIT_FIELD_PILE, HandManager.DISCARD_PILE, HandManager.PILE_INSERTION_STRATEGIES.TOP, HandManager.PLAYER_DEFAULT_HAND_CARD_COUNT_MAX, true, true)
#endregion

func _on_unit_spawn_requested(card_data: CardData, unit_name: String, unit_strength: int, unit_stamina: int, unit_owner: int) -> void:
	spawn_unit(card_data, unit_name, unit_strength, unit_stamina, unit_owner)

func _on_unit_changed(_unit: Unit) -> void:
	update_tally()

## Pulse the readout when the tug of war resolves.
func _on_tug_of_war_resolved(_player_strength: int, _enemy_strength: int) -> void:
	_tally_label.pivot_offset = _tally_label.size / 2
	var tween: Tween = create_tween()
	tween.tween_property(_tally_label, "scale", Vector2(1.3, 1.3), TALLY_FLASH_TIME / 2)
	tween.tween_property(_tally_label, "scale", Vector2.ONE, TALLY_FLASH_TIME / 2)

func _on_combat_started(_event_id: String) -> void:
	clear_units()

func _on_combat_ended() -> void:
	clear_units()

func _on_run_ended() -> void:
	clear_units()
