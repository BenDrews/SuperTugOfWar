## Shows one enemy's intent for one lane, at the right end of the lane between it and the enemy.
## Icons reuse the enemy intent textures. Hovering it shows a tooltip, and if the intent summons
## units, a faded preview of them appears at the back of the enemy's line in that lane.
## Built in code by UnitLane.set_lane_intents().
extends PanelContainer
class_name LaneIntentDisplay

const ICON_SIZE: Vector2 = Vector2(26, 26)
const FLASH_TIME: float = 0.5

## Intent icon textures, keyed by EnemyIntentData.INTENT_DISPLAY_TYPES.
const INTENT_DISPLAY_TYPE_TO_TEXTURE_PATH: Dictionary[int, String] = {
	EnemyIntentData.INTENT_DISPLAY_TYPES.ATTACKING: "res://sprites/intents/enemy_intent_attacking.png",
	EnemyIntentData.INTENT_DISPLAY_TYPES.BLOCKING: "res://sprites/intents/enemy_intent_blocking.png",
	EnemyIntentData.INTENT_DISPLAY_TYPES.DEBUFFING: "res://sprites/intents/enemy_intent_debuffing.png",
	EnemyIntentData.INTENT_DISPLAY_TYPES.BUFFING: "res://sprites/intents/enemy_intent_buffing.png",
	EnemyIntentData.INTENT_DISPLAY_TYPES.SUMMONING: "res://sprites/intents/enemy_intent_summoning.png",
}

## Emitted on hover with the units this intent would summon (see get_unit_summons()).
signal preview_requested(display: LaneIntentDisplay)
signal preview_cleared(display: LaneIntentDisplay)

var enemy: Enemy = null
var enemy_intent: EnemyIntentData = null
var lane_index: int = 0

func init(_enemy: Enemy, _enemy_intent: EnemyIntentData, _lane_index: int) -> void:
	enemy = _enemy
	enemy_intent = _enemy_intent
	lane_index = _lane_index
	mouse_filter = Control.MOUSE_FILTER_STOP

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.35)
	style.border_color = Unit.ENEMY_UNIT_COLOR
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(3)
	add_theme_stylebox_override("panel", style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	add_child(vbox)

	var icon_row: HBoxContainer = HBoxContainer.new()
	icon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	icon_row.add_theme_constant_override("separation", 0)
	vbox.add_child(icon_row)
	for display_type: int in enemy_intent.enemy_intent_display_types:
		var texture_path: String = INTENT_DISPLAY_TYPE_TO_TEXTURE_PATH.get(display_type, "")
		if texture_path == "":
			continue
		var icon: TextureRect = TextureRect.new()
		icon.texture = load(texture_path)
		icon.custom_minimum_size = ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_row.add_child(icon)

	var amount_label: Label = Label.new()
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	amount_label.add_theme_font_size_override("font_size", 13)
	amount_label.text = get_amount_text()
	amount_label.visible = amount_label.text != ""
	vbox.add_child(amount_label)

	tooltip_text = get_description()
	mouse_entered.connect(func(): preview_requested.emit(self))
	mouse_exited.connect(func(): preview_cleared.emit(self))

## Units this intent summons: [{unit_name, unit_strength, unit_stamina, lane_position}].
func get_unit_summons() -> Array[Dictionary]:
	var summons: Array[Dictionary] = []
	for custom_action: Dictionary in enemy_intent.enemy_intent_custom_actions:
		for action_script_path: String in custom_action:
			if action_script_path != Scripts.ACTION_SUMMON_UNIT and action_script_path != Scripts.ACTION_PLACE_UNIT:
				continue
			var action_values: Dictionary = custom_action[action_script_path]
			# a summon pointed at a different lane doesn't preview here
			if action_values.get("lane_index", lane_index) != lane_index:
				continue
			summons.append({
				"unit_name": action_values.get("unit_name", enemy.enemy_data.enemy_name + " Unit"),
				"unit_strength": int(action_values.get(CardData.UNIT_STRENGTH_KEY, 0)),
				"unit_stamina": int(action_values.get(CardData.UNIT_STAMINA_KEY, 1)),
				"lane_position": int(action_values.get("lane_position", -1)),
			})
	return summons

func _get_attack_preview() -> Vector2i:
	if lane_index < len(enemy.lane_intent_attack_previews):
		return enemy.lane_intent_attack_previews[lane_index]
	return enemy.get_intent_attack_preview(enemy_intent)

## Short numbers under the icons, eg "6" or "3x2" for attacks, "+5" for block, "3/2" for a summon.
func get_amount_text() -> String:
	var parts: Array[String] = []
	var attack: Vector2i = _get_attack_preview()
	if attack.x * attack.y > 0:
		parts.append(str(attack.x) if attack.y == 1 else "%dx%d" % [attack.x, attack.y])
	if enemy_intent.enemy_intent_block > 0:
		parts.append("+%d" % enemy_intent.enemy_intent_block)
	for summon: Dictionary in get_unit_summons():
		parts.append("%d/%d" % [summon.unit_strength, summon.unit_stamina])
	if len(parts) == 0 and len(enemy_intent.enemy_intent_display_types) == 0:
		return "-" # resting
	return " ".join(parts)

## Plain-text tooltip describing what the intent will do.
func get_description() -> String:
	var intent_name: String = enemy_intent.enemy_intent_overrides_id.trim_prefix("intent_").capitalize() # "summon_grunt" -> "Summon Grunt"
	var lines: Array[String] = ["%s: %s" % [enemy.enemy_data.enemy_name, intent_name]]
	var attack: Vector2i = _get_attack_preview()
	if attack.x * attack.y > 0:
		lines.append("Attack for %d" % attack.x if attack.y == 1 else "Attack for %d x %d" % [attack.x, attack.y])
	if enemy_intent.enemy_intent_block > 0:
		lines.append("Gain %d block" % enemy_intent.enemy_intent_block)
	for summon: Dictionary in get_unit_summons():
		lines.append("Place %s in this lane (Strength %d, Stamina %d)" % [summon.unit_name, summon.unit_strength, summon.unit_stamina])
	if enemy_intent.enemy_intent_display_types.has(EnemyIntentData.INTENT_DISPLAY_TYPES.BUFFING):
		lines.append("Buff")
	if enemy_intent.enemy_intent_display_types.has(EnemyIntentData.INTENT_DISPLAY_TYPES.DEBUFFING):
		lines.append("Debuff you")
	if len(lines) == 1:
		lines.append("Nothing this turn")
	return "\n".join(lines)

## Pulse, used while this intent is being performed.
func flash() -> void:
	pivot_offset = size / 2
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), FLASH_TIME / 2)
	tween.tween_property(self, "scale", Vector2.ONE, FLASH_TIME / 2)
