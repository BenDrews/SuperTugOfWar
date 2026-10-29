# maintains combat UI
extends Control

@onready var money_label: Label = $%MoneyLabel
@onready var health_label: Label = $%HealthLabel

@onready var energy_count: Label = $Energy/EnergyCount
@onready var energy: TextureButton = $Energy
@onready var draw_count: Label = $DrawPile/DrawCount
@onready var discard_count: Label = $DiscardPile/DiscardCount
@onready var exhaust_count: Label = $ExhaustPile/ExhaustCount

@onready var deck_button: TextureButton = %DeckButton
@onready var draw_pile_button: TextureButton = %DrawPile
@onready var discard_pile_button: TextureButton = %DiscardPile
@onready var exhaust_pile_button: TextureButton = %ExhaustPile

@onready var card_selection_overlay = $%CardSelectionOverlay

@onready var combat_animation_player: AnimationPlayer = $CombatAnimation
@onready var enemy_container = $EnemyContainer

@onready var player = $Player
@onready var hand = $Hand
@onready var chest = $Chest
@onready var shop = $Shop

@onready var background_button: TextureButton = %BackgroundButton

@onready var end_turn_button: Button = $EndTurnButton
var end_turn_object: CombatEndTurn = null

## The three tug of war lanes, between the player (left) and the enemies (right).
## Created in code; the player and enemy positions it sits between are set in Root.tscn.
var battlefield: Battlefield = null
const BATTLEFIELD_RECT: Rect2 = Rect2(208, 116, 768, 360)

func _ready():
	_create_battlefield()
	
	Signals.player_money_changed.connect(_on_player_money_changed)
	Signals.player_health_changed.connect(_on_player_health_changed)
	
	Signals.enemy_killed.connect(_on_enemy_killed)
	Signals.enemy_death_animation_finished.connect(_on_enemy_death_animation_finished)
	
	Signals.combat_started.connect(_on_combat_started)
	Signals.combat_ended.connect(_on_combat_ended)
	
	Signals.player_turn_started.connect(_on_player_turn_started)
	Signals.player_turn_ended.connect(_on_player_turn_ended)
	Signals.enemy_turn_ended.connect(_on_enemy_turn_ended)
	Signals.enemy_turn_started.connect(_on_enemy_turn_started)
	
	Signals.end_turn_requested.connect(_on_end_turn_requested)
	
	end_turn_button.button_up.connect(_on_end_turn_button_up)
	
	update_combat_display()
	player.update_player_display(Global.player_data)
	
	# pile buttons
	deck_button.button_up.connect(_on_deck_button_up)
	draw_pile_button.button_up.connect(_on_draw_pile_button_up)
	discard_pile_button.button_up.connect(_on_discard_pile_button_up)
	exhaust_pile_button.button_up.connect(_on_exhaust_pile_button_up)
	
	# updating pile counts when cards do things
	Signals.card_played.connect(_on_card_played)	# player is playing card
	Signals.card_drawn.connect(_on_card_drawn)
	Signals.card_deck_shuffled.connect(_on_card_deck_shuffled)
	Signals.card_discarded.connect(_on_card_discarded)
	Signals.card_exhausted.connect(_on_card_exhausted)
	
	Signals.energy_changed.connect(_on_energy_changed)
	Signals.card_queue_refunded.connect(_on_card_queue_refunded)
	
	Signals.run_started.connect(_on_run_started)
	Signals.run_ended.connect(_on_run_ended)
	
	Signals.map_location_selected.connect(_on_map_location_selected)
	
	# map back references
	HandManager.card_destination_to_ui_elements[HandManager.DECK] = deck_button
	HandManager.card_destination_to_ui_elements[HandManager.DRAW_PILE] = draw_pile_button
	HandManager.card_destination_to_ui_elements[HandManager.DISCARD_PILE] = discard_pile_button
	HandManager.card_destination_to_ui_elements[HandManager.EXHAUST_PILE] = exhaust_pile_button

func _create_battlefield() -> void:
	battlefield = Battlefield.new()
	battlefield.name = "Battlefield"
	battlefield.visible = false
	add_child(battlefield)
	# draw above the combatants but below the hand, card picking and overlays
	move_child(battlefield, enemy_container.get_index() + 1)
	battlefield.position = BATTLEFIELD_RECT.position
	battlefield.size = BATTLEFIELD_RECT.size

func _on_map_location_selected(location_data: LocationData):
	# determine what to do when the player visits a new location
	var location_type: int = location_data.location_type
	
	chest.visible = false
	shop.visible = false
	
	set_combat_display_visibility(false)
	
	match location_type:
		LocationData.LOCATION_TYPES.COMBAT, LocationData.LOCATION_TYPES.MINIBOSS, LocationData.LOCATION_TYPES.BOSS:
			ActionGenerator.generate_combat_start("") # emit empty event to get location's combat event
		LocationData.LOCATION_TYPES.TREASURE:
			chest.visible = true
		LocationData.LOCATION_TYPES.SHOP:
			shop.visible = true
	
	_update_background()
	
	ActionGenerator.generate_location_music_action()

func update_combat_display():
	energy_count.text = str(Global.player_data.player_energy) + "/" + str(Global.player_data.player_energy_max)
	draw_count.text = str(len(HandManager.player_draw))
	discard_count.text = str(len(HandManager.player_discard))
	exhaust_count.text = str(len(HandManager.player_exhaust))
	_on_player_health_changed()
	_on_player_money_changed()

func _update_background() -> void:
	# set the background if possible
	var background_texture_path: String = ""
	
	var act_id: String = Global.player_data.player_act_id
	var act_data: ActData = Global.get_act_data(act_id)
	var location_data: LocationData = Global.get_player_location_data()
	
	# act background
	if act_data.act_background_texture_path != "":
		background_texture_path = act_data.act_background_texture_path
	# location background
	if location_data.location_background_texture_path != "":
		background_texture_path = location_data.location_background_texture_path
	# event background
	var location_event_object_id: String = location_data.get_location_event_object_id()
	if location_event_object_id != "":
		var event_data: EventData = Global.get_event_data(location_event_object_id)
		if event_data.event_background_texture_path != "":
			background_texture_path = event_data.event_background_texture_path
	
	if background_texture_path != "":
		background_button.texture_normal = FileLoader.load_texture(background_texture_path)
	

func set_combat_display_visibility(display_visibility: bool) -> void:
	energy.visible = display_visibility
	draw_pile_button.visible = display_visibility
	discard_pile_button.visible = display_visibility
	exhaust_pile_button.visible = display_visibility
	end_turn_button.visible = display_visibility
	battlefield.visible = display_visibility

func _on_card_played(_card_play_request: CardPlayRequest):
	update_combat_display()

func _on_card_drawn(_card_data: CardData):
	update_combat_display()

func _on_card_deck_shuffled(_is_reshuffle: bool):
	update_combat_display()

func _on_card_discarded(_card_data: CardData, _is_manual_discard: bool):
	update_combat_display()

func _on_card_exhausted(_card_data: CardData):
	update_combat_display()

func _on_energy_changed():
	update_combat_display()

func _on_card_queue_refunded():
	update_combat_display()

func _on_player_money_changed(_delta: int = 0):
	money_label.text = "$%s" % Global.player_data.player_money

func _on_player_health_changed():
	health_label.text = "%s / %s" % [Global.player_data.player_health, Global.player_data.player_health_max]

### Deck Buttons

func _on_deck_button_up():
	card_selection_overlay.view_deck()
func _on_draw_pile_button_up():
	card_selection_overlay.view_draw_pile()
func _on_discard_pile_button_up():
	card_selection_overlay.view_discard()
func _on_exhaust_pile_button_up():
	card_selection_overlay.view_exhaust()

### Turn Handling

func _on_enemy_killed(enemy: Enemy):
	var generated_actions: Array[BaseAction] = ActionGenerator.create_actions(enemy, null, [], enemy.enemy_data.enemy_actions_on_death, null)
	ActionHandler.add_actions(generated_actions)
	
	
func _on_enemy_death_animation_finished(_enemy: Enemy):
	# determine if all non minion enemies killed and end combat
	var enemies: Array[Enemy] = []
	enemies.assign(get_tree().get_nodes_in_group("enemies"))
	
	var non_minion_enemies_remain: bool = true
	for enemy in enemies:
		if not enemy.enemy_data.enemy_is_minion:
			non_minion_enemies_remain = false
	
	if non_minion_enemies_remain:
		# wait for actions to finish and end combat
		if ActionHandler.actions_being_performed:
			await ActionHandler.actions_ended
		end_combat()

func _on_combat_started(event_id: String):
	var current_event: EventData = null
	if event_id == "":
		# if no event is provided, it will be derived from the location
		var current_location: LocationData = Global.get_player_location_data()
		current_event = Global.get_player_event_data()
		current_location.location_visited = true
	else:
		current_event = Global.get_event_data(event_id)
	
	enemy_container.populate_enemies_from_event(current_event)
	start_turn_animation()
	
	Global.player_data.player_energy = Global.player_data.player_energy_max
	set_combat_display_visibility(true)
	update_combat_display()
	
func _on_combat_ended():
	set_combat_display_visibility(false)
	
## Helper method to cut down on code bloat. Used in player/enemy turn logic to short circuit
## the turn logic if either player or enemies are dead.
func _end_combat_check() -> bool:
	var combat_is_ended: bool = false
	if not Global.are_remaining_enemies():
		end_combat()
		combat_is_ended = true
	if not player.is_alive():
		player.play_death_animation()
		combat_is_ended = true
	return combat_is_ended

func perform_enemy_turn():
	# generates enemy actions and performs them in order
	var enemies: Array[Enemy] = Global.get_alive_enemies()
	if _end_combat_check():
		return
	
	# Perform start of turn status logic for all enemies
	# enemies, then enemy-side lane statuses, then enemy units (see Battlefield.get_side_status_holders())
	await battlefield.process_side_status_effects(Unit.UNIT_OWNERS.ENEMY, StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.PRE_ENEMY_TURN)
	if _end_combat_check():
		return
	
	### Perform intent for all enemies
	var field_pre_intent_statuses_done: bool = false
	for e in enemies:
		# get enemy standard attack data
		var enemy: Enemy = e	# typecast iterator
		
		### perform enemy start of turn statuses
		if enemy.is_alive():
			enemy.perform_status_effect_process_actions(StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.PRE_ENEMY_INTENT)
			if ActionHandler.actions_being_performed:
				await ActionHandler.actions_ended
			# enemy-side lane and unit statuses with this per-intent time run once, with the first living enemy
			if not field_pre_intent_statuses_done:
				field_pre_intent_statuses_done = true
				await battlefield.process_side_status_effects(Unit.UNIT_OWNERS.ENEMY, StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.PRE_ENEMY_INTENT, false, true)
		
		### perform intents: block resets once, then each lane's intent runs, top to bottom
		if enemy.is_alive():
			var reset_block_data: Array[Dictionary] = [{
				Scripts.ACTION_RESET_BLOCK: {
					"target_override": BaseAction.TARGET_OVERRIDES.PARENT,
					"time_delay": 0.0
					}
				}]
			ActionHandler.add_actions(ActionGenerator.create_actions(enemy, null, [player], reset_block_data, null))
			if ActionHandler.actions_being_performed:
				await ActionHandler.actions_ended
		
		for lane_index: int in Battlefield.LANE_COUNT:
			if not enemy.is_alive():
				break
			var lane_intent: EnemyIntentData = enemy.enemy_data.get_current_lane_intent(lane_index)
			if lane_intent == null:
				continue
			await _perform_enemy_lane_intent(enemy, lane_intent, lane_index)
			# if player is dead stop
			if _end_combat_check():
				return
		
		### Perform enemy end of turn statuses
		if enemy.is_alive():
			enemy.perform_status_effect_process_actions(StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.POST_ENEMY_INTENT)
			if ActionHandler.actions_being_performed:
				await ActionHandler.actions_ended
		# enemy-side lane and unit statuses with this per-intent time run once, with the last enemy
		if enemy == enemies[-1]:
			await battlefield.process_side_status_effects(Unit.UNIT_OWNERS.ENEMY, StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.POST_ENEMY_INTENT, false, true)
		
		if _end_combat_check():
			return
	
	if ActionHandler.actions_being_performed:
		await ActionHandler.actions_ended
	
	# tug of war, now that the enemy's intents (and any units they placed) are done: the enemy is
	# pulled in lanes where the player is stronger, then player units tire
	if _end_combat_check():
		return
	ActionGenerator.generate_end_of_turn_unit_actions(Unit.UNIT_OWNERS.ENEMY)
	if ActionHandler.actions_being_performed:
		await ActionHandler.actions_ended
	if _end_combat_check():
		return
	
	# Perform end of turn status logic for all enemies
	await battlefield.process_side_status_effects(Unit.UNIT_OWNERS.ENEMY, StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.POST_ENEMY_TURN)

	# all enemies dead
	if _end_combat_check():
		return
	else:
		Signals.enemy_turn_ended.emit()


	
## Performs one of an enemy's lane intents: its custom actions (eg summoning a unit, which goes into
## this lane unless the action names a lane), its attacks, and its block. Waits until finished.
func _perform_enemy_lane_intent(enemy: Enemy, enemy_intent: EnemyIntentData, lane_index: int) -> void:
	# NOTE: remember these go in reverse order on the stack
	var enemy_actions_data: Array[Dictionary] = []
	for custom_action: Dictionary in enemy_intent.enemy_intent_custom_actions:
		var lane_custom_action: Dictionary = {}
		for action_script_path: String in custom_action:
			var action_values: Dictionary = custom_action[action_script_path].duplicate()
			if not action_values.has("lane_index"):
				action_values["lane_index"] = lane_index
			lane_custom_action[action_script_path] = action_values
		enemy_actions_data.append(lane_custom_action)
	
	# attacks
	if enemy_intent.enemy_intent_number_of_attacks > 0:
		enemy_actions_data.append({
			Scripts.ACTION_ATTACK_GENERATOR: {
				"damage": enemy_intent.enemy_intent_attack_damage,
				"number_of_attacks": enemy_intent.enemy_intent_number_of_attacks,
				"impact_vfx_animation_id": enemy_intent.enemy_intent_attack_impact_animation_id,
				"time_delay": EnemyData.ENEMY_ATTACK_DELAY,
				"audio_path": enemy_intent.enemy_intent_audio_path,
				"lane_index": lane_index,
				}
			})
	
	# block
	if enemy_intent.enemy_intent_block > 0:
		enemy_actions_data.append({
			Scripts.ACTION_BLOCK: {
				"block": enemy_intent.enemy_intent_block,
				"target_override": BaseAction.TARGET_OVERRIDES.PARENT,
				"time_delay": 0.0,
				}
			})
	
	# play intent sound if one exists and no attacks
	if enemy_intent.enemy_intent_audio_path != "" and enemy_intent.enemy_intent_number_of_attacks == 0:
		ActionGenerator.generate_sound_action(enemy_intent.enemy_intent_audio_path, false)
	
	Signals.enemy_lane_intent_performed.emit(enemy, lane_index)
	var enemy_actions: Array[BaseAction] = ActionGenerator.create_actions(enemy, null, [player], enemy_actions_data, null)
	ActionHandler.add_actions(enemy_actions)
	if ActionHandler.actions_being_performed:
		await ActionHandler.actions_ended

func _on_player_turn_started():
	# prevent player from playing cards manually
	HandManager.set_disable_hand(true)
	
	# first turn actions
	if StatsHandler.get_turn_count() == 1:
		# location initial actions
		var location_data: LocationData = Global.get_player_location_data()
		assert(location_data != null)
		if location_data != null:
			var card_play_request: CardPlayRequest = HandManager.create_card_play_request(null, null, false, true)
			card_play_request.card_data = null
			card_play_request.selected_target = null
			
			# perform location initial actions
			var location_initial_combat_actions: Array[BaseAction] = ActionGenerator.create_actions(player, card_play_request, [], location_data.location_initial_combat_actions, null)
			ActionHandler.add_actions(location_initial_combat_actions)
		
			# wait for first turn actions
			if ActionHandler.actions_being_performed:
				await ActionHandler.actions_ended
			
			# perform event initial actions
			var event_data: EventData = Global.get_player_event_data()
			var event_initial_combat_actions: Array[BaseAction] = ActionGenerator.create_actions(player, card_play_request, [], event_data.event_initial_combat_actions, null)
			ActionHandler.add_actions(event_initial_combat_actions)
			
			# wait for first turn actions
			if ActionHandler.actions_being_performed:
				await ActionHandler.actions_ended
			
			if _end_combat_check():
				return
		
		# combat start consumable actions
		for consumable_slot_index: int in Global.player_data.player_consumable_slot_count:
			var consumable_data: ConsumableData = Global.get_player_consumable_in_slot_index(consumable_slot_index)
			if consumable_data != null:
				if len(consumable_data.consumable_initial_combat_actions) > 0:
					var card_play_request: CardPlayRequest = HandManager.create_card_play_request(null, null, false, true) # generate fake request
					
					# perform initial actions
					var consumable_actions: Array[BaseAction] = ActionGenerator.create_actions(null, card_play_request, [], consumable_data.consumable_initial_combat_actions, null)
					ActionHandler.add_actions(consumable_actions)
	
		# wait for first turn actions
		if ActionHandler.actions_being_performed:
			await ActionHandler.actions_ended
		# if player is dead stop
		if _end_combat_check():
			return
		
		# combat start card actions
		for card_data: CardData in HandManager.player_draw:
			var card_play_request: CardPlayRequest = HandManager.create_card_play_request(card_data, null, true, true) # generate fake request
			
			# perform initial actions
			var card_play_actions: Array[BaseAction] = ActionGenerator.create_actions(player, card_play_request, [], card_data.card_initial_combat_actions, null)
			ActionHandler.add_actions(card_play_actions)
	
		# wait for first turn actions
		if ActionHandler.actions_being_performed:
			await ActionHandler.actions_ended
		# if player is dead stop
		if _end_combat_check():
			return
	
	# reset energy
	ActionGenerator.generate_start_of_turn_energy_actions()
	
	# perform pre draw actions
	player.update_incoming_damage_amount(true)
	player.generate_reset_block_action()
	# player, then player-side lane statuses, then player units (see Battlefield.get_side_status_holders())
	await battlefield.process_side_status_effects(Unit.UNIT_OWNERS.PLAYER, StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.PRE_DRAW_PLAYER_START_TURN)
	if _end_combat_check():
		return
	
	# draw cards
	ActionGenerator.generate_start_of_turn_draw_actions()
	if ActionHandler.actions_being_performed:
		await ActionHandler.actions_ended
	# if player is dead stop
	if _end_combat_check():
		return
	
	# perform post draw actions
	await battlefield.process_side_status_effects(Unit.UNIT_OWNERS.PLAYER, StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.POST_DRAW_PLAYER_START_TURN)
	# if player is dead stop
	if _end_combat_check():
		return
	
	# unlock and update hand
	HandManager.set_disable_hand(false)
	hand.update_hand_card_display()

func _on_player_turn_ended():
	# prevent player from playing cards
	HandManager.set_disable_hand(true)
	
	# perform all end of turn actions and await
	await battlefield.process_side_status_effects(Unit.UNIT_OWNERS.PLAYER, StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.PRE_DISCARD_PLAYER_END_TURN)
	if _end_combat_check():
		return
	
	# discard non retained cards and perform card actions
	HandManager.perform_end_of_turn_hand_actions()
	if ActionHandler.actions_being_performed:
		await ActionHandler.actions_ended
	if _end_combat_check():
		return
	
	# tug of war: the player is pulled in lanes where the enemy is stronger, then enemy units tire
	ActionGenerator.generate_end_of_turn_unit_actions(Unit.UNIT_OWNERS.PLAYER)
	if ActionHandler.actions_being_performed:
		await ActionHandler.actions_ended
	if _end_combat_check():
		return
	
	# perform all end of turn actions and await
	await battlefield.process_side_status_effects(Unit.UNIT_OWNERS.PLAYER, StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.POST_DISCARD_PLAYER_END_TURN)
	if _end_combat_check():
		return

func _on_player_start_turn_animation_finished():
	# called from animation player
	start_turn()

func _on_player_end_turn_animation_finished():
	# called from animation player
	Signals.player_turn_ended.emit()
	
	# wait for all end of turn actions to process
	if ActionHandler.actions_being_performed:
		await ActionHandler.actions_ended
	
	# start enemy turn if they're alive
	if len(get_tree().get_nodes_in_group("enemies")) > 0:
		Signals.enemy_turn_started.emit()

func _on_enemy_turn_started():
	perform_enemy_turn()
	
func _on_enemy_turn_ended():
	start_turn_animation()
	
func _on_end_turn_button_up():
	queue_end_turn(CombatEndTurn.END_TURN_QUEUE_IMMEDIACY.WAIT_FOR_ALL_CARD_PLAYS)

func _on_end_turn_requested(immediacy: int):
	queue_end_turn(immediacy)

func queue_end_turn(immediacy: int = CombatEndTurn.END_TURN_QUEUE_IMMEDIACY.WAIT_FOR_ALL_CARD_PLAYS):
	# queues up an end turn, using async objects with priority to determine how to handle it
	if end_turn_object == null:
		end_turn_object = CombatEndTurn.new(self, immediacy)
		end_turn_object.wait()
		end_turn_button.disabled = true
	elif immediacy > end_turn_object.end_turn_queue_value:
		# higher priority end turn, replace the old with a newer one
		end_turn_object.disable()	# stop the old one working
		end_turn_object = CombatEndTurn.new(self, immediacy)
		end_turn_object.wait()

func _reset_turn_end_queue() -> void:
	if end_turn_object != null:
		end_turn_object.disable()
		end_turn_object = null

func _on_run_started():
	visible = true
	_on_player_health_changed()
	_on_player_money_changed()
	
	# load energy
	var character_data: CharacterData = Global.get_player_character_data()
	if character_data != null:
		var color_data: ColorData = Global.get_color_data(character_data.character_color_id)
		if color_data != null:
			energy.texture_normal = FileLoader.load_texture(color_data.color_energy_icon_texture_path)
	
func _on_run_ended():
	visible = false
	_reset_turn_end_queue()

func start_combat() -> void:
	_reset_turn_end_queue()

## Performs end of combat logic and signals end of combat
func end_combat() -> void:
	var event_data: EventData = Global.get_player_event_data()
	if event_data != null:
		# perform event initial actions
		var event_post_combat_actions: Array[BaseAction] = ActionGenerator.create_actions(player, null, [], event_data.event_post_combat_actions, null)
		ActionHandler.add_actions(event_post_combat_actions)

		if ActionHandler.actions_being_performed:
			await ActionHandler.actions_ended
	
	_reset_turn_end_queue()
	Signals.combat_ended.emit()

func end_turn():
	pass

func start_turn():
	# called from animation player
	_reset_turn_end_queue()
	update_combat_display()
	Signals.player_turn_started.emit()

func end_turn_animation() -> void:
	_reset_turn_end_queue()
	combat_animation_player.play("end_turn")
	
func start_turn_animation() -> void:
	combat_animation_player.play("start_turn")
