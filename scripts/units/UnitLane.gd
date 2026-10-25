## One lane of the battlefield. Laid out left to right as:
##   [player units ... front] [tally] [front ... enemy units]
## Each side keeps its units in order, index 0 being the front (closest to the rope in the middle).
## Units are positioned manually so a crowded side squeezes together instead of overflowing.
## Lasting lane effects (BaseLaneEffect, usually from lane powers) show as badges in the top-left corner.
## The right end of the lane holds the enemy intents for this lane (LaneIntentDisplay), between the
## lane and the enemy. Hovering a summon intent previews the units at the back of the enemy line.
## Also handles being picked by the player (see Battlefield and ActionBasePickLanes), optionally
## with an insertion position on the player's side.
## Built in code by Battlefield.
extends Control
class_name UnitLane

## Emitted while picking when the player clicks this lane. lane_position is the insertion
## index on the player's side under the mouse (0 = front), or -1 when not picking a position.
signal lane_clicked(lane: UnitLane, lane_position: int)

const SIDE_PADDING: float = 10.0
const TALLY_WIDTH: float = 88.0
## Room at the right end of the lane for enemy intents.
const INTENT_WIDTH: float = 60.0
const INTENT_GAP: float = 6.0
const UNIT_SEPARATION: float = 6.0
const LAYOUT_TWEEN_TIME: float = 0.2
const TALLY_FLASH_TIME: float = 0.6

const TALLY_PLAYER_WINNING_COLOR: Color = Color(0.55, 0.9, 0.55)
const TALLY_ENEMY_WINNING_COLOR: Color = Color(1.0, 0.5, 0.45)
const LANE_BG_COLOR: Color = Color(1, 1, 1, 0.04)
const LANE_BORDER_COLOR: Color = Color(1, 1, 1, 0.12)
const LANE_PICKABLE_BORDER_COLOR: Color = Color(1.0, 0.85, 0.3, 0.7)
const LANE_HOVER_BG_COLOR: Color = Color(1.0, 0.85, 0.3, 0.14)
const INSERT_MARKER_COLOR: Color = Color(1.0, 0.85, 0.3)

var lane_index: int = 0
## Ordered front to back.
var player_units: Array[Unit] = []
## Ordered front to back.
var enemy_units: Array[Unit] = []
## Faded stand-ins shown while an enemy summon intent is hovered. Laid out after enemy_units.
var preview_units: Array[Unit] = []
## Lasting effects on this lane for the rest of combat. See add_lane_effect().
var lane_effects: Array[BaseLaneEffect] = []

var is_pickable: bool = false
var picks_position: bool = false
var _is_hovered: bool = false
var _hover_insert_index: int = -1

var _background: Panel = null
var _background_style: StyleBoxFlat = null
var _player_side: Control = null
var _enemy_side: Control = null
var _tally_label: Label = null
var _insert_marker: ColorRect = null
var _intent_box: VBoxContainer = null
var _effect_badges: HBoxContainer = null

func init(_lane_index: int) -> void:
	lane_index = _lane_index
	name = "Lane%d" % lane_index
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_background_style = StyleBoxFlat.new()
	_background_style.set_corner_radius_all(10)
	_background_style.set_border_width_all(2)
	_background = Panel.new()
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.add_theme_stylebox_override("panel", _background_style)
	add_child(_background)

	_player_side = _make_side("PlayerSide")
	_enemy_side = _make_side("EnemySide")

	_tally_label = Label.new()
	_tally_label.name = "Tally"
	_tally_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tally_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tally_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tally_label.add_theme_font_size_override("font_size", 22)
	add_child(_tally_label)

	_insert_marker = ColorRect.new()
	_insert_marker.color = INSERT_MARKER_COLOR
	_insert_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_insert_marker.visible = false
	_player_side.add_child(_insert_marker)

	_effect_badges = HBoxContainer.new()
	_effect_badges.name = "LaneEffects"
	_effect_badges.position = Vector2(SIDE_PADDING, 3)
	_effect_badges.add_theme_constant_override("separation", 4)
	_effect_badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_effect_badges)
	
	_intent_box = VBoxContainer.new()
	_intent_box.name = "Intents"
	_intent_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_intent_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intent_box.add_theme_constant_override("separation", 2)
	add_child(_intent_box)
	
	mouse_exited.connect(_on_mouse_exited)
	resized.connect(_layout_regions)
	_update_background()
	update_tally()

func _make_side(side_name: String) -> Control:
	var side: Control = Control.new()
	side.name = side_name
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(side)
	return side

#region Units
## Returns one side's units, front to back.
func get_side_units(unit_owner: int) -> Array[Unit]:
	return enemy_units if unit_owner == Unit.UNIT_OWNERS.ENEMY else player_units

## Returns units in this lane. Pass a Unit.UNIT_OWNERS value for only one side.
func get_units(unit_owner: int = Unit.UNIT_OWNER_AUTOMATIC) -> Array[Unit]:
	if unit_owner == Unit.UNIT_OWNERS.PLAYER:
		return player_units.duplicate()
	if unit_owner == Unit.UNIT_OWNERS.ENEMY:
		return enemy_units.duplicate()
	return player_units + enemy_units

func get_total_strength(unit_owner: int) -> int:
	var total: int = 0
	for unit: Unit in get_side_units(unit_owner):
		total += unit.unit_strength
	return total

## Adds a unit to its owner's side. lane_position is the index to insert at (0 = front);
## -1 or anything past the end adds it to the back of the line.
func add_unit(unit: Unit, lane_position: int = -1) -> void:
	var side_units: Array[Unit] = get_side_units(unit.unit_owner)
	var side: Control = _enemy_side if unit.is_enemy_unit() else _player_side
	if lane_position < 0 or lane_position > len(side_units):
		lane_position = len(side_units)
	side_units.insert(lane_position, unit)
	unit.lane = self
	side.add_child(unit)
	unit.position = _get_unit_slot_position(unit.unit_owner, lane_position, len(side_units)) # appear in place, others slide
	_layout_units(unit.unit_owner)
	update_tally()

## Removes a unit from the lane's ordering (does not free it).
func remove_unit(unit: Unit) -> void:
	player_units.erase(unit)
	enemy_units.erase(unit)
	_layout_units(unit.unit_owner)
	update_tally()

## Frees every unit in the lane without touching their cards.
func clear_units() -> void:
	for unit: Unit in player_units + enemy_units:
		unit.clear_unit()
	player_units.clear()
	enemy_units.clear()
	clear_unit_previews()
	update_tally()
#endregion

#region Tally
func update_tally() -> void:
	if _tally_label == null:
		return
	var player_strength: int = get_total_strength(Unit.UNIT_OWNERS.PLAYER)
	var enemy_strength: int = get_total_strength(Unit.UNIT_OWNERS.ENEMY)
	_tally_label.text = "%d  vs  %d" % [player_strength, enemy_strength]
	# while previewing a summon intent, show what the enemy side will become
	var preview_strength: int = 0
	for preview_unit: Unit in preview_units:
		preview_strength += preview_unit.unit_strength
	if preview_strength > 0:
		_tally_label.text = "%d  vs  %d\n(%d)" % [player_strength, enemy_strength, enemy_strength + preview_strength]
	_tally_label.visible = len(player_units) + len(enemy_units) + len(preview_units) > 0
	if player_strength > enemy_strength:
		_tally_label.modulate = TALLY_PLAYER_WINNING_COLOR
	elif enemy_strength > player_strength:
		_tally_label.modulate = TALLY_ENEMY_WINNING_COLOR
	else:
		_tally_label.modulate = Color.WHITE

## Pulses the tally, used when this lane's tug of war resolves.
func flash_tally() -> void:
	_tally_label.pivot_offset = _tally_label.size / 2
	var tween: Tween = create_tween()
	tween.tween_property(_tally_label, "scale", Vector2(1.35, 1.35), TALLY_FLASH_TIME / 2)
	tween.tween_property(_tally_label, "scale", Vector2.ONE, TALLY_FLASH_TIME / 2)
#endregion

#region Layout
## Width of the lane itself, excluding the intent slot on the right.
func _get_field_width() -> float:
	return size.x - INTENT_WIDTH - INTENT_GAP

func _get_side_width() -> float:
	return max((_get_field_width() - TALLY_WIDTH - SIDE_PADDING * 2) / 2, Unit.UNIT_SIZE.x)

func _layout_regions() -> void:
	var side_width: float = _get_side_width()
	_background.position = Vector2.ZERO
	_background.size = Vector2(_get_field_width(), size.y)
	_intent_box.position = Vector2(_get_field_width() + INTENT_GAP, 0)
	_intent_box.size = Vector2(INTENT_WIDTH, size.y)
	_player_side.position = Vector2(SIDE_PADDING, 0)
	_player_side.size = Vector2(side_width, size.y)
	_tally_label.position = Vector2(SIDE_PADDING + side_width, 0)
	_tally_label.size = Vector2(TALLY_WIDTH, size.y)
	_enemy_side.position = Vector2(SIDE_PADDING + side_width + TALLY_WIDTH, 0)
	_enemy_side.size = Vector2(side_width, size.y)
	_insert_marker.size = Vector2(4, Unit.UNIT_SIZE.y + 8)
	_layout_units(Unit.UNIT_OWNERS.PLAYER, false)
	_layout_units(Unit.UNIT_OWNERS.ENEMY, false)

## Distance between neighbouring units on a side; shrinks so a crowded side still fits.
func _get_unit_step(unit_count: int) -> float:
	var step: float = Unit.UNIT_SIZE.x + UNIT_SEPARATION
	if unit_count > 1:
		var fit_step: float = (_get_side_width() - Unit.UNIT_SIZE.x) / (unit_count - 1)
		step = min(step, fit_step)
	return step

## Where the unit at index lane_position sits within its side. Player fronts are on the right
## edge of the player side, enemy fronts on the left edge of the enemy side.
func _get_unit_slot_position(unit_owner: int, lane_position: int, unit_count: int) -> Vector2:
	var step: float = _get_unit_step(unit_count)
	var y: float = (size.y - Unit.UNIT_SIZE.y) / 2
	if unit_owner == Unit.UNIT_OWNERS.ENEMY:
		return Vector2(lane_position * step, y)
	return Vector2(_get_side_width() - Unit.UNIT_SIZE.x - lane_position * step, y)

func _layout_units(unit_owner: int, animate: bool = true) -> void:
	var side_units: Array[Unit] = get_side_units(unit_owner)
	if unit_owner == Unit.UNIT_OWNERS.ENEMY:
		side_units = side_units + preview_units # previews stand at the back of the enemy line
	var unit_count: int = len(side_units)
	for i: int in unit_count:
		var unit: Unit = side_units[i]
		var target: Vector2 = _get_unit_slot_position(unit_owner, i, unit_count)
		# front units draw on top when squeezed
		unit.z_index = unit_count - i
		if animate and is_inside_tree():
			create_tween().tween_property(unit, "position", target, LAYOUT_TWEEN_TIME)
		else:
			unit.position = target
#endregion

#region Lane Effects
## Adds a lasting effect to this lane, stacking onto a matching one if present.
func add_lane_effect(lane_effect_script_path: String, amount: int, effect_values: Dictionary) -> BaseLaneEffect:
	for lane_effect: BaseLaneEffect in lane_effects:
		if lane_effect.stacks_with(lane_effect_script_path, effect_values):
			lane_effect.amount += amount
			_update_effect_badges()
			Signals.lane_effects_changed.emit(lane_index)
			return lane_effect
	var lane_effect: BaseLaneEffect = load(lane_effect_script_path).new()
	lane_effect.init(lane_effect_script_path, amount, effect_values, lane_index)
	lane_effects.append(lane_effect)
	_update_effect_badges()
	Signals.lane_effects_changed.emit(lane_index)
	return lane_effect

func clear_lane_effects() -> void:
	lane_effects.clear()
	_update_effect_badges()

## Lets this lane's effects adjust a unit about to be placed here. See BaseLaneEffect.modify_unit_summon().
func apply_lane_effects_to_summon(summon: Dictionary) -> void:
	for lane_effect: BaseLaneEffect in lane_effects:
		lane_effect.modify_unit_summon(summon)

func _update_effect_badges() -> void:
	for child: Node in _effect_badges.get_children():
		child.queue_free()
	for lane_effect: BaseLaneEffect in lane_effects:
		var badge: PanelContainer = PanelContainer.new()
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.45, 0.25, 0.85)
		style.set_corner_radius_all(4)
		style.content_margin_left = 5
		style.content_margin_right = 5
		badge.add_theme_stylebox_override("panel", style)
		badge.mouse_filter = Control.MOUSE_FILTER_PASS
		badge.tooltip_text = lane_effect.get_description()
		var label: Label = Label.new()
		label.text = lane_effect.get_badge_text()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 11)
		badge.add_child(label)
		_effect_badges.add_child(badge)
#endregion

#region Enemy Intents
## Replaces the intent displays in this lane's slot. Hovering one previews its summons.
func set_lane_intents(displays: Array[LaneIntentDisplay]) -> void:
	clear_unit_previews()
	for child: Node in _intent_box.get_children():
		child.queue_free()
	for display: LaneIntentDisplay in displays:
		display.preview_requested.connect(_on_intent_preview_requested)
		display.preview_cleared.connect(_on_intent_preview_cleared)
		_intent_box.add_child(display)

func get_lane_intents() -> Array[LaneIntentDisplay]:
	var displays: Array[LaneIntentDisplay] = []
	for child: Node in _intent_box.get_children():
		if child is LaneIntentDisplay and not child.is_queued_for_deletion():
			displays.append(child)
	return displays

## Shows faded stand-ins for units about to be summoned on the enemy side.
func show_unit_previews(summons: Array[Dictionary]) -> void:
	clear_unit_previews()
	for summon: Dictionary in summons:
		var preview_unit: Unit = Unit.new()
		preview_unit.init_preview(summon.unit_name, summon.unit_strength, summon.unit_stamina, Unit.UNIT_OWNERS.ENEMY)
		_enemy_side.add_child(preview_unit)
		preview_units.append(preview_unit)
		preview_unit.position = _get_unit_slot_position(Unit.UNIT_OWNERS.ENEMY, len(enemy_units) + len(preview_units) - 1, len(enemy_units) + len(preview_units))
	_layout_units(Unit.UNIT_OWNERS.ENEMY)
	update_tally()

func clear_unit_previews() -> void:
	if len(preview_units) == 0:
		return
	for preview_unit: Unit in preview_units:
		preview_unit.queue_free()
	preview_units.clear()
	_layout_units(Unit.UNIT_OWNERS.ENEMY)
	update_tally()

func _on_intent_preview_requested(display: LaneIntentDisplay) -> void:
	var summons: Array[Dictionary] = display.get_unit_summons()
	if len(summons) > 0:
		show_unit_previews(summons)

func _on_intent_preview_cleared(_display: LaneIntentDisplay) -> void:
	clear_unit_previews()
#endregion

#region Picking
## Called by Battlefield when a lane pick starts/ends.
func set_pickable(pickable: bool, _picks_position: bool = false) -> void:
	is_pickable = pickable
	picks_position = _picks_position and pickable
	mouse_filter = Control.MOUSE_FILTER_STOP if pickable else Control.MOUSE_FILTER_IGNORE
	# units swallow nothing while picking, so the whole lane is one click target
	for unit: Unit in player_units + enemy_units:
		unit.mouse_filter = Control.MOUSE_FILTER_IGNORE if pickable else Control.MOUSE_FILTER_PASS
	if not pickable:
		_is_hovered = false
		_hover_insert_index = -1
		_insert_marker.visible = false
	_update_background()

## Insertion index on the player side for a point in lane coordinates. 0 = in front of everyone.
func get_insert_index_at(lane_local_x: float) -> int:
	var side_x: float = lane_local_x - _player_side.position.x
	var unit_count: int = len(player_units)
	var index: int = 0
	for i: int in unit_count:
		var center_x: float = _get_unit_slot_position(Unit.UNIT_OWNERS.PLAYER, i, unit_count).x + Unit.UNIT_SIZE.x / 2
		if center_x > side_x:
			index = i + 1 # the mouse is behind (left of) this unit
	return index

func _update_insert_marker() -> void:
	if not (picks_position and _is_hovered):
		_insert_marker.visible = false
		return
	var unit_count: int = len(player_units)
	var step: float = _get_unit_step(unit_count + 1) # leave room for the new unit
	var marker_x: float = _get_side_width() - _hover_insert_index * step + UNIT_SEPARATION / 2 - 2
	if unit_count > 0:
		var front_edge: float = _get_unit_slot_position(Unit.UNIT_OWNERS.PLAYER, 0, unit_count).x + Unit.UNIT_SIZE.x
		var back_edge: float = _get_unit_slot_position(Unit.UNIT_OWNERS.PLAYER, unit_count - 1, unit_count).x
		if _hover_insert_index == 0:
			marker_x = front_edge + UNIT_SEPARATION / 2 - 2
		elif _hover_insert_index >= unit_count:
			marker_x = back_edge - UNIT_SEPARATION / 2 - 2
		else:
			var ahead_left: float = _get_unit_slot_position(Unit.UNIT_OWNERS.PLAYER, _hover_insert_index - 1, unit_count).x
			var behind_right: float = _get_unit_slot_position(Unit.UNIT_OWNERS.PLAYER, _hover_insert_index, unit_count).x + Unit.UNIT_SIZE.x
			marker_x = (ahead_left + behind_right) / 2 - 2
	_insert_marker.position = Vector2(clamp(marker_x, 0, _get_side_width() - 4), (size.y - _insert_marker.size.y) / 2)
	_insert_marker.visible = true

func _gui_input(event: InputEvent) -> void:
	if not is_pickable:
		return
	if event is InputEventMouseMotion:
		_is_hovered = true
		_hover_insert_index = get_insert_index_at(event.position.x) if picks_position else -1
		_update_insert_marker()
		_update_background()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		var lane_position: int = get_insert_index_at(event.position.x) if picks_position else -1
		lane_clicked.emit(self, lane_position)

func _on_mouse_exited() -> void:
	_is_hovered = false
	_insert_marker.visible = false
	_update_background()

func _update_background() -> void:
	if _background_style == null:
		return
	_background_style.bg_color = LANE_HOVER_BG_COLOR if (is_pickable and _is_hovered) else LANE_BG_COLOR
	_background_style.border_color = LANE_PICKABLE_BORDER_COLOR if is_pickable else LANE_BORDER_COLOR
#endregion
