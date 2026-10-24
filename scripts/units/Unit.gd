## A Unit on the battlefield, summoned by playing a Unit card (see ActionPlaceUnit / ActionSummonUnit).
## Lives in one UnitLane on its owner's side. Holds the unit's live Strength and Stamina.
## Stamina drops by 1 at the end of each player turn (ActionDecayUnitStamina); at 0 the unit is
## discarded and its card goes to the discard pile.
## Visuals are built in code so no scene file is needed. Positioned by its UnitLane.
extends PanelContainer
class_name Unit

## All live (not yet discarded) units are in this group.
const UNITS_GROUP: String = "units"

## Which side of the tug of war a unit pulls for.
enum UNIT_OWNERS {PLAYER, ENEMY}
## Pass as unit_owner to infer the owner from who summoned the unit. See ActionSummonUnit.
const UNIT_OWNER_AUTOMATIC: int = -1
## Panel color for enemy units (player units use their card's color).
const ENEMY_UNIT_COLOR: Color = Color(0.6, 0.25, 0.65)

const UNIT_SIZE: Vector2 = Vector2(76, 88)
const FADE_TIME: float = 0.25

## The card that summoned this unit. Can be null for units created by non-card effects.
var card_data: CardData = null
var unit_name: String = ""
var unit_owner: int = UNIT_OWNERS.PLAYER
var unit_strength: int = 0
var unit_stamina: int = 0
## Stamina the unit was summoned with, for display.
var unit_stamina_max: int = 0
## The lane this unit is in. Set by UnitLane.add_unit().
var lane: UnitLane = null
## Set once the unit starts leaving the field, so it is never processed twice.
var is_discarded: bool = false
## A faded stand-in shown while hovering an enemy intent that will summon this unit. Not a real
## unit: not in UNITS_GROUP, not in any lane's ordering, never pulls.
var is_preview: bool = false

const PREVIEW_ALPHA: float = 0.45

var _name_label: Label = null
var _strength_label: Label = null
var _stamina_label: Label = null

func init(_card_data: CardData, _unit_name: String, _unit_strength: int, _unit_stamina: int, _unit_owner: int = UNIT_OWNERS.PLAYER) -> void:
	card_data = _card_data
	unit_name = _unit_name
	unit_owner = _unit_owner
	unit_strength = _unit_strength
	unit_stamina = _unit_stamina
	unit_stamina_max = _unit_stamina

	add_to_group(UNITS_GROUP)
	_build_visuals()
	update_unit_display()

	# fade in
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_TIME)

func is_player_unit() -> bool:
	return unit_owner == UNIT_OWNERS.PLAYER

func is_enemy_unit() -> bool:
	return unit_owner == UNIT_OWNERS.ENEMY

## Index of the lane this unit is in, or -1 if not in one.
func get_lane_index() -> int:
	if lane == null:
		return -1
	return lane.lane_index

## Position within its side of the lane. 0 is the front (closest to the rope in the middle).
func get_lane_position() -> int:
	if lane == null:
		return -1
	return lane.get_side_units(unit_owner).find(self)

## Sets up a preview (ghost) unit. See is_preview.
func init_preview(_unit_name: String, _unit_strength: int, _unit_stamina: int, _unit_owner: int = UNIT_OWNERS.ENEMY) -> void:
	is_preview = true
	unit_name = _unit_name
	unit_owner = _unit_owner
	unit_strength = _unit_strength
	unit_stamina = _unit_stamina
	unit_stamina_max = _unit_stamina
	_build_visuals()
	update_unit_display()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", PREVIEW_ALPHA, FADE_TIME / 2)

#region Stats
## Changes stamina by a delta. Does not discard the unit by itself; see ActionDecayUnitStamina
## and BaseLaneAction which discard at 0.
func change_stamina(delta: int) -> void:
	if is_discarded or delta == 0:
		return
	unit_stamina = max(unit_stamina + delta, 0)
	update_unit_display()
	Signals.unit_stamina_changed.emit(self)

## Changes strength by a delta, clamped at 0.
func change_strength(delta: int) -> void:
	if is_discarded or delta == 0:
		return
	unit_strength = max(unit_strength + delta, 0)
	update_unit_display()
	Signals.unit_strength_changed.emit(self)
#endregion

## Removes the unit from the battlefield and sends its card from the field pile to the discard pile.
func discard_unit() -> void:
	if is_discarded:
		return
	is_discarded = true
	remove_from_group(UNITS_GROUP)
	if lane != null:
		lane.remove_unit(self) # the rest of the line closes up while this one fades in place

	# only move the card if it's still sitting in the field pile (an interceptor may have sent it elsewhere)
	if card_data != null and HandManager.get_card_pile_location_name(card_data) == HandManager.UNIT_FIELD_PILE:
		if not Battlefield.is_card_on_field(card_data):	# another unit from the same card (eg a duplicated play) still needs it
			HandManager.move_card_to_pile(card_data, HandManager.UNIT_FIELD_PILE, HandManager.DISCARD_PILE, HandManager.PILE_INSERTION_STRATEGIES.TOP, HandManager.PLAYER_DEFAULT_HAND_CARD_COUNT_MAX, true, true)

	Signals.unit_discarded.emit(self)

	# fade out then free
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(queue_free)

## Immediately frees the unit without touching its card. Used when combat ends and the deck is reset anyway.
func clear_unit() -> void:
	is_discarded = true
	remove_from_group(UNITS_GROUP)
	lane = null
	queue_free()

#region Visuals
func update_unit_display() -> void:
	if _name_label == null:
		return
	_name_label.text = unit_name
	_strength_label.text = "STR %d" % unit_strength
	_stamina_label.text = "STA %d/%d" % [unit_stamina, unit_stamina_max]
	# warn when this is the unit's last turn
	_stamina_label.modulate = Color.ORANGE if unit_stamina <= 1 else Color.WHITE
	tooltip_text = "%s (%s)\nStrength: %d\nStamina: %d (leaves the field when it hits 0)" % [unit_name, "Enemy" if is_enemy_unit() else "Yours", unit_strength, unit_stamina]

func _build_visuals() -> void:
	custom_minimum_size = UNIT_SIZE
	size = UNIT_SIZE
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	mouse_filter = Control.MOUSE_FILTER_PASS # allow tooltips without blocking clicks

	var unit_color: Color = Color(0.35, 0.35, 0.4)
	if is_enemy_unit():
		unit_color = ENEMY_UNIT_COLOR
	elif card_data != null:
		var color_data: ColorData = Global.get_color_data(card_data.card_color_id)
		if color_data != null:
			unit_color = color_data.color

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = unit_color.darkened(0.55)
	style.border_color = unit_color
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(4)
	add_theme_stylebox_override("panel", style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 0)
	add_child(vbox)

	_name_label = _make_label(12)
	_name_label.clip_text = true
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_strength_label = _make_label(16)
	_stamina_label = _make_label(12)
	vbox.add_child(_name_label)
	vbox.add_child(_strength_label)
	vbox.add_child(_stamina_label)

func _make_label(font_size: int) -> Label:
	var label: Label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	return label
#endregion
