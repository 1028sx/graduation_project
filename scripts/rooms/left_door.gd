extends Area2D

#region 導出參數
@export var direction: String = "left"
@export var spawn_point: String = "Left"
#endregion

#region 變量
var player_in_area := false
var is_transitioning := false
var room_cleared := false
@onready var animated_sprite = $AnimatedSprite2D
@onready var interaction_label = $Label_Interaction
#endregion

#region 生命週期函數
func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	monitoring = true
	
	# 初始化時隱藏門和標籤
	modulate.a = 0
	if interaction_label:
		interaction_label.hide()
	
	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_animation_finished)
		animated_sprite.stop()  # 確保一開始沒有動畫播放
	
	_connect_signals()

func _process(_delta: float) -> void:
	if player_in_area and Input.is_action_just_pressed("jump"):
		_transition_room()
#endregion

#region 信號連接
func _connect_signals() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	await get_tree().process_frame
	
	var enemy_manager = get_tree().get_first_node_in_group("enemy_manager")
	if enemy_manager:
		if enemy_manager.all_enemies_defeated.is_connected(_on_all_enemies_defeated):
			enemy_manager.all_enemies_defeated.disconnect(_on_all_enemies_defeated)
		enemy_manager.all_enemies_defeated.connect(_on_all_enemies_defeated)

func _on_all_enemies_defeated() -> void:
	room_cleared = true
	modulate.a = 1  # 顯示門
	
	if animated_sprite:
		animated_sprite.play("start")

func _on_animation_finished() -> void:
	if animated_sprite and animated_sprite.animation == "start":
		animated_sprite.play("idle")
#endregion

#region 信號處理
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_area = true
		if room_cleared and interaction_label:
			interaction_label.show()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_area = false
		if interaction_label:
			interaction_label.hide()
#endregion

#region 房間切換
func _get_and_remove_managers() -> Array:
	var managers = []
	
	var enemy_manager = get_tree().get_first_node_in_group("enemy_manager")
	if enemy_manager:
		enemy_manager.name = "EnemyManager"
		if enemy_manager.get_parent():
			enemy_manager.get_parent().remove_child(enemy_manager)
		managers.append(enemy_manager)
		
		var room_manager = _get_room_manager()
		if room_manager:
			var current_room = room_manager.get_current_room()
			enemy_manager.save_room_state(current_room)
	
	var item_manager = get_tree().get_first_node_in_group("item_manager")
	if item_manager:
		item_manager.name = "ItemManager"
		if item_manager.get_parent():
			item_manager.get_parent().remove_child(item_manager)
		managers.append(item_manager)
	
	return managers

func _place_managers_in_new_scene(managers: Array, new_scene: Node) -> void:
	if not new_scene:
		return
		
	for manager in managers:
		if not manager:
			continue
			
		if manager.get_parent():
			manager.get_parent().remove_child(manager)
		new_scene.add_child(manager)
		
		if manager.is_in_group("enemy_manager"):
			manager.name = "EnemyManager"

func _transition_room() -> void:
	if is_transitioning:
		return
	
	is_transitioning = true
	
	var room_manager = _get_room_manager()
	if not room_manager:
		is_transitioning = false
		return
		
	var current_room = room_manager.get_current_room()
	var target_room = room_manager.get_connected_room(current_room, direction)
	if target_room.is_empty():
		is_transitioning = false
		return
	
	var current_player = _get_and_remove_player()
	var current_uis = _get_and_remove_ui()
	var current_managers = _get_and_remove_managers()
	
	if not current_player:
		is_transitioning = false
		return
	
	var scene_path = "res://scenes/rooms/Room%s.tscn" % target_room.trim_prefix("room")
	var packed_scene = load(scene_path)
	if not packed_scene:
		is_transitioning = false
		return
	
	var new_scene = packed_scene.instantiate()
	
	MetSys.room_changed.emit(current_room, target_room)
	
	_switch_scene(new_scene)
	_place_player_in_new_scene(current_player, new_scene)
	_place_ui_in_new_scene(current_uis, new_scene)
	_place_managers_in_new_scene(current_managers, new_scene)
	
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	var enemy_manager = get_tree().get_first_node_in_group("enemy_manager")
	if enemy_manager:
		enemy_manager.spawn_enemies_for_room(target_room)
	
	is_transitioning = false
#endregion

#region 輔助函數
func _get_and_remove_player() -> Node2D:
	var current_player = get_tree().get_first_node_in_group("player")
	if current_player:
		if current_player.current_state == "death":
			return null
		current_player.get_parent().remove_child(current_player)
	return current_player

func _get_and_remove_ui() -> Array:
	var uis = []
	
	var main_ui = get_tree().get_first_node_in_group("ui")
	if main_ui and main_ui.get_parent():
		main_ui.get_parent().remove_child(main_ui)
		uis.append(main_ui)
	
	var loot_ui = get_tree().get_first_node_in_group("loot_selection_ui")
	if loot_ui and loot_ui.get_parent():
		loot_ui.get_parent().remove_child(loot_ui)
		uis.append(loot_ui)
	
	return uis

func _switch_scene(new_scene: Node) -> void:
	var root = get_tree().root
	var current_scene = get_tree().current_scene
	
	root.add_child(new_scene)
	if current_scene:
		current_scene.queue_free()
	get_tree().current_scene = new_scene

func _place_player_in_new_scene(player: Node2D, new_scene: Node) -> void:
	if not player or not new_scene:
		return
	
	new_scene.add_child(player)
	
	var target_spawn_point = "LeftSpawn" if spawn_point == "Right" else "RightSpawn"
	var spawn_points = new_scene.get_node_or_null("SpawnPoints")
	
	if spawn_points:
		var target_spawn = spawn_points.get_node_or_null(target_spawn_point)
		if target_spawn:
			player.global_position = target_spawn.global_position
	
	await get_tree().process_frame
	
	var ui = get_tree().get_first_node_in_group("ui")
	if ui and ui.has_method("connect_player_signals"):
		ui.connect_player_signals()

func _place_ui_in_new_scene(uis: Array, new_scene: Node) -> void:
	if new_scene:
		for ui in uis:
			if not ui:
				continue
			
			new_scene.add_child(ui)
			
			if ui.is_in_group("ui"):
				_setup_main_ui(ui)
			elif ui.is_in_group("loot_selection_ui"):
				ui.hide()
		
		var global_ui = get_node_or_null("/root/GlobalUi")
		if global_ui:
			global_ui.setup_inventory()

func _setup_main_ui(ui: Node) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		if player.health_changed.is_connected(ui._on_player_health_changed):
			player.health_changed.disconnect(ui._on_player_health_changed)
		player.health_changed.connect(ui._on_player_health_changed)
		if ui.has_method("_update_health_bar"):
			ui._update_health_bar(player)

func _get_room_manager() -> Node:
	var room_manager = get_node_or_null("/root/RoomManager")
	if room_manager:
		return room_manager
	
	room_manager = get_tree().root.get_node_or_null("RoomManager")
	if room_manager:
		return room_manager
	
	return null
#endregion
