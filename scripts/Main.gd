extends Node2D

#region 節點引用
@onready var player = $Player
@onready var room_manager = $RoomManager
@onready var enemy_manager = $EnemyManager
@onready var item_manager = $ItemManager
@onready var ui = $UI
@onready var game_manager = $GameManager
#endregion

#region 狀態變量
var screen_size: Vector2
var world_size: Vector2
#endregion

#region 初始化
func _ready():
	_initialize_game()
	_setup_test_room()

func _initialize_game():
	_connect_signals()
	_initialize_sizes()

func _connect_signals():
	if room_manager and room_manager.has_signal("room_changed"):
		room_manager.connect("room_changed", Callable(self, "_on_room_changed"))
	if enemy_manager and enemy_manager.has_signal("all_enemies_defeated"):
		enemy_manager.connect("all_enemies_defeated", Callable(self, "_on_all_enemies_defeated"))

func _initialize_sizes():
	screen_size = get_viewport_rect().size
	world_size = Vector2(1920, 1080)

func _setup_test_room():
	var test_room = load("res://scenes/rooms/TestRoom.tscn").instantiate()
	add_child(test_room)
	
	_setup_player_position(test_room)
	_spawn_initial_enemies(test_room)

func _setup_player_position(test_room):
	var player_start = test_room.get_node("PlayerStart")
	if is_instance_valid(player_start):
		player.global_position = player_start.global_position

func _spawn_initial_enemies(test_room):
	var enemy_spawn_points = test_room.get_node("EnemySpawnPoints")
	if is_instance_valid(enemy_spawn_points) and enemy_spawn_points.get_child_count() > 0:
		_spawn_archer(test_room, enemy_spawn_points)
		_spawn_boar(test_room, enemy_spawn_points)

func _spawn_archer(test_room, spawn_points):
	var archer = enemy_manager.enemy_scenes["archer"].instantiate()
	archer.global_position = spawn_points.get_child(0).global_position
	test_room.add_child(archer)

func _spawn_boar(test_room, spawn_points):
	var boar = enemy_manager.enemy_scenes["boar"].instantiate()
	boar.global_position = spawn_points.get_child(0).global_position + Vector2(100, 0)
	test_room.add_child(boar)
#endregion

#region 遊戲系統
func _input(event):
	if event.is_action_pressed("pause"):
		_toggle_pause()

func _toggle_pause():
	get_tree().paused = not get_tree().paused
	if get_tree().paused:
		ui.show_pause_menu()
	else:
		ui.hide_pause_menu()

func spawn_enemy(enemy_scene, spawn_position: Vector2):
	var enemy = enemy_scene.instantiate()
	enemy.global_position = spawn_position
	_setup_enemy_collision(enemy)
	add_child(enemy)

func _setup_enemy_collision(enemy):
	enemy.collision_layer = 0b0010
	enemy.collision_mask = 0b0001
	
	if enemy.has_node("AttackArea"):
		enemy.get_node("AttackArea").collision_layer = 0b1000
		enemy.get_node("AttackArea").collision_mask = 0b0100

func spawn_enemies():
	var enemy_spawn_points = get_tree().get_nodes_in_group("enemy_spawn")
	for spawn_point in enemy_spawn_points:
		if is_instance_valid(enemy_manager):
			var enemy = enemy_manager.enemy_scenes["archer"].instantiate()
			enemy.global_position = spawn_point.global_position
			add_child(enemy)
#endregion

#region 升級系統
func get_upgrade_description(upgrade) -> String:
	match upgrade:
		"speed_boost": return "增加移動速度 20%"
		"damage_up": return "增加攻擊力 15%"
		"unlock_shuriken": return "解鎖手裡劍技能"
		"unlock_special_attack": return "解鎖特殊攻擊技能"
		"unlock_block": return "解鎖格擋技能"
	return "未知升級"

func apply_upgrade(upgrade: String):
	if player and game_manager:
		match upgrade:
			"unlock_block":
				player.unlock_skill("block")
		game_manager.next_level()

func get_unlocked_skills() -> Array:
	var skills = []
	if player.can_throw_shuriken:
		skills.append(load("res://assets/players/Sprites/shuriken.png"))
	if player.can_special_attack:
		skills.append("special_attack")
	if player.can_block:
		skills.append("block")
	return skills
#endregion

#region 遊戲管理
func start_new_game():
	if game_manager:
		game_manager.reset_game()

func save_game():
	if game_manager:
		game_manager.save_game()

func load_game():
	if game_manager:
		game_manager.load_game()

func set_music_volume(volume: float):
	if game_manager:
		game_manager.set_music_volume(volume)

func set_sfx_volume(volume: float):
	if game_manager:
		game_manager.set_sfx_volume(volume)
#endregion

#region 信號處理
func _on_room_changed(new_room):
	if enemy_manager and game_manager:
		enemy_manager.spawn_enemies_for_room(new_room, game_manager.current_difficulty)

func _on_all_enemies_defeated():
	if game_manager:
		game_manager.increase_difficulty()
		game_manager.add_score(100)
	if ui:
		ui.show_upgrade_menu()

func _on_player_health_changed(new_health):
	if ui and game_manager:
		ui.update_hud(new_health, game_manager.score)

func _on_upgrade_option_selected(upgrade):
	var description = get_upgrade_description(upgrade)
	if ui:
		ui.update_upgrade_description(description)

func _on_player_died():
	if game_manager:
		game_manager.game_over()

func _on_player_skill_unlocked(_skill_name):
	ui.update_skill_icons(get_unlocked_skills())
#endregion
