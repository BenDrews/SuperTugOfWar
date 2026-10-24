extends BaseCombatant
class_name Enemy

@onready var enemy_intent: HBoxContainer = $Visible/Intent

# icons used for displaying specific intent types
@onready var attacking_intent: TextureRect = $Visible/Intent/AttackingIntent
@onready var blocking_intent: TextureRect = $Visible/Intent/BlockingIntent
@onready var debuffing_intent: TextureRect = $Visible/Intent/DebuffingIntent
@onready var buffing_intent: TextureRect = $Visible/Intent/BuffingIntent
@onready var summoning_intent: TextureRect = $Visible/Intent/SummoningIntent

# maps the EnemyIntentData.enemy_intent_display_type to the texture to display
@onready var INTENT_DISPLAY_TYPE_TO_INTENT: Dictionary[int, TextureRect] = {
	EnemyIntentData.INTENT_DISPLAY_TYPES.ATTACKING: attacking_intent,
	EnemyIntentData.INTENT_DISPLAY_TYPES.BLOCKING: blocking_intent,
	EnemyIntentData.INTENT_DISPLAY_TYPES.DEBUFFING: debuffing_intent,
	EnemyIntentData.INTENT_DISPLAY_TYPES.BUFFING: buffing_intent,
	EnemyIntentData.INTENT_DISPLAY_TYPES.SUMMONING: summoning_intent,
}

@onready var enemy_intent_amount_label: Label = $Visible/Intent/IntentAmount

@onready var name_label = %NameLabel
@onready var death_animation_player: AnimationPlayer = $DeathAnimationPlayer

var enemy_data: EnemyData = null
var enemy_slot: int = 0 # the spawn slot the enemy is in

var enemy_intent_attack_damage: int = 0
var enemy_intent_number_of_attacks: int = 0
## Intercepted (damage, number of attacks) for each lane's current intent. See update_enemy_intent().
var lane_intent_attack_previews: Array[Vector2i] = []

func init(_enemy_data: EnemyData):
	enemy_data = _enemy_data
	
	selection_button.mouse_entered.connect(_on_mouse_entered)
	selection_button.mouse_exited.connect(_on_mouse_exited)
	
	animated_sprite_2d.sprite_frames = get_animation_sprite_frames()
	animated_sprite_2d.play(AnimationData.ANIMATION_IDLE)
	
	# apply initial effects
	for status_effect_object_id in enemy_data.enemy_initial_status_effects.keys():
		var charge_amount: int = enemy_data.enemy_initial_status_effects[status_effect_object_id]
		add_status_effect_charges(status_effect_object_id, charge_amount)
	
	name_label.text = enemy_data.enemy_name
	
	# update_health_bar()
	layered_health_bar.init(enemy_data.enemy_health, enemy_data.enemy_health_max)
	
func get_animation_data() -> AnimationData:
	var animation_data: AnimationData = Global.get_animation_data(enemy_data.enemy_animation_id)
	return animation_data

## Does damage to combatant and returns [unblocked damage dealt, damage to 0 (if enemy dies), overkill damage (if enemy dies)]
## eg 15 damage on 10 remaining health and 3 block will return [12, 10, 2].
## bypass_block = true will do damage directly to health.
func damage(_damage: int, bypass_block: bool = false) -> Array[int]:
	var bypassed_damage: int = _damage # raw unblocked damage
	var bypassed_damage_capped: int = 0 # damage done that does not factor in overkill damage
	var overkill_damage: int = 0 # damage done past 0
	
	if enemy_data.enemy_block > 0 and not bypass_block:
		if enemy_data.enemy_block > _damage:
			# damage less than block
			enemy_data.enemy_block -= _damage
			bypassed_damage = 0
			create_block_text()
			Signals.combatant_blocked.emit(self, _damage)
		else:
			# damage exceeds block
			bypassed_damage = _damage - enemy_data.enemy_block
			enemy_data.enemy_block = 0
			Signals.combatant_block_broken.emit(self)
	
	block.visible = enemy_data.enemy_block > 0
	block_amount.text = str(enemy_data.enemy_block)
	
	if bypassed_damage <= 0:
		return [0,0,0]
	
	create_damage_text(bypassed_damage)
	
	overkill_damage = max(0, bypassed_damage - enemy_data.enemy_health)
	bypassed_damage_capped = bypassed_damage - overkill_damage
	
	# check health to prevent multiple deaths
	if enemy_data.enemy_health > 0:
		# damage the enemy
		enemy_data.enemy_health = max(0, enemy_data.enemy_health - bypassed_damage)
		Signals.combatant_damaged.emit(self, bypassed_damage, bypassed_damage_capped, overkill_damage)
		
		# generate an interceptable action and intercept it to possibly change health
		if enemy_data.enemy_health <= 0:
			ActionGenerator.generate_combatant_death(self)
		
		# update healthbar and potentially kill enemy
		update_health_bar(true)
		if enemy_data.enemy_health <= 0:
			if not death_animation_player.is_playing():
				animated_sprite_2d.play(AnimationData.ANIMATION_DEATH)
				death_animation_player.play("Enemy/death")
				remove_from_group("enemies")
				Signals.enemy_killed.emit(self)
	
	return [bypassed_damage, bypassed_damage_capped, overkill_damage]

func set_block(amount: int) -> void:
	enemy_data.enemy_block = amount
	enemy_data.enemy_block = max(0, enemy_data.enemy_block)
	
	block.visible = enemy_data.enemy_block > 0
	block_amount.text = str(enemy_data.enemy_block)

func get_block() -> int:
	return enemy_data.enemy_block

func add_block(amount: int) -> void:
	set_block(enemy_data.enemy_block + amount)
	if amount > 0:
		create_block_fade()
		Signals.combatant_block_added.emit(self)

#region Health
func heal_percentage(percent: float):
	var percentage_health: int = int(ceil(float(enemy_data.enemy_health_max) * percent))
	add_health(percentage_health, 0)

func add_health(health_amount: int, health_amount_max: int = 0) -> void:
	set_health(enemy_data.enemy_health + health_amount, enemy_data.enemy_health_max + health_amount_max)

func set_health(health_amount: int, health_amount_max: int = enemy_data.enemy_health_max) -> void:
	var is_damaged: bool = health_amount < enemy_data.enemy_health
	
	enemy_data.enemy_health_max = max(1, enemy_data.enemy_health_max)
	enemy_data.enemy_health = clamp(0, health_amount, enemy_data.enemy_health_max)
	
	update_health_bar(is_damaged)

func update_health_bar(as_damage: bool = false) -> void:
	if as_damage:
		layered_health_bar.apply_damage(enemy_data.enemy_health, enemy_data.enemy_health_max, status_id_to_status_effects)
	else:
		layered_health_bar.update_health_layers(enemy_data.enemy_health, enemy_data.enemy_health_max, status_id_to_status_effects)

func get_combatant_health() -> int:
	return enemy_data.enemy_health

func get_combatant_health_max() -> int:
	return enemy_data.enemy_health_max

#endregion

## Changes each of the enemy's lane intents to the next intent in their random walks.
func cycle_enemy_intent():
	enemy_data.cycle_lane_intents()
	update_enemy_intent()
	Signals.enemy_intent_changed.emit()

## Super Tug of War: intents are shown per lane by the Battlefield (LaneIntentDisplay), so the
## overhead intent is hidden. This recalculates the intercepted attack previews for every lane,
## which the lane displays, the player's incoming damage and is_attacking() use.
func update_enemy_intent():
	enemy_intent.visible = false
	
	lane_intent_attack_previews.clear()
	enemy_intent_attack_damage = 0
	enemy_intent_number_of_attacks = 0
	for lane_index: int in Battlefield.LANE_COUNT:
		var preview: Vector2i = get_intent_attack_preview(enemy_data.get_current_lane_intent(lane_index))
		lane_intent_attack_previews.append(preview)
		if preview.x * preview.y > 0:
			# legacy fields: the biggest single attack, and the total number of hits across lanes
			enemy_intent_attack_damage = max(enemy_intent_attack_damage, preview.x)
			enemy_intent_number_of_attacks += preview.y

## Intercepted (damage per hit, number of hits) an intent would deal to the player, as shown to them.
func get_intent_attack_preview(intent: EnemyIntentData) -> Vector2i:
	if intent == null:
		return Vector2i.ZERO
	var player: Player = Global.get_player()
	var attack_damage: int = intent.enemy_intent_attack_damage
	var number_of_attacks: int = intent.enemy_intent_number_of_attacks
	
	# damage: intercept an attack action in preview mode
	var action_data: Array[Dictionary] = [{
		Scripts.ACTION_ATTACK: {
			"damage": attack_damage,
			"target_override": BaseAction.TARGET_OVERRIDES.PLAYER
			}}]
	var generated_action: BaseAction = ActionGenerator.create_actions(self, null, [player], action_data, null)[0]
	var action_interceptor_processors: Array[ActionInterceptorProcessor] = generated_action._intercept_action([player], true)
	if len(action_interceptor_processors) == 1:
		attack_damage = max(0, action_interceptor_processors[0].get_shadowed_action_values("damage", 0))
	
	# number of attacks: intercept an attack generator in preview mode
	action_data = [{
		Scripts.ACTION_ATTACK_GENERATOR: {
			"damage": intent.enemy_intent_attack_damage,
			"number_of_attacks": number_of_attacks,
			"target_override": BaseAction.TARGET_OVERRIDES.PLAYER
			}}]
	generated_action = ActionGenerator.create_actions(self, null, [player], action_data, null)[0]
	action_interceptor_processors = generated_action._intercept_action([player], true)
	if len(action_interceptor_processors) == 1:
		number_of_attacks = max(0, action_interceptor_processors[0].get_shadowed_action_values("number_of_attacks", 0))
	
	return Vector2i(attack_damage, number_of_attacks)

## Total intercepted damage this enemy's lane intents will deal to the player this turn.
func get_incoming_damage() -> int:
	var total: int = 0
	for preview: Vector2i in lane_intent_attack_previews:
		total += preview.x * preview.y
	return total

func is_alive() -> bool:
	return enemy_data.enemy_health > 0

func is_attacking() -> bool:
	return get_incoming_damage() > 0

func _on_combat_started(_event_id: String):
	pass

func _on_combat_ended():
	queue_free()

func _on_player_turn_started():
	cycle_enemy_intent()

func _on_selection_button_up():
	if is_alive():
		Signals.enemy_clicked.emit(self)

func _on_mouse_entered():
	Signals.enemy_hovered.emit(self)
	name_label.visible = true

func _on_mouse_exited():
	Signals.enemy_hovered.emit(null)
	name_label.visible = false

func _on_death_animtation_finished():
	# called from animation player
	Signals.enemy_death_animation_finished.emit(self)
