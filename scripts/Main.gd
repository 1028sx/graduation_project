extends Node2D

@onready var player = $Player
@onready var camera = $Camera2D
@onready var room_manager = $RoomManager
@onready var enemy_manager = $EnemyManager
@onready var item_manager = $ItemManager
@onready var ui = $UI
@onready var game_manager = $GameManager

var screen_size: Vector2
var world_size: Vector2

func _ready():
	print("Main _ready function called")
	
	# 檢查所有節點是否正確引用
	print("Player node exists: ", is_instance_valid(player))
	print("Camera node exists: ", is_instance_valid(camera))
	print("RoomManager node exists: ", is_instance_valid(room_manager))
	print("EnemyManager node exists: ", is_instance_valid(enemy_manager))
	print("ItemManager node exists: ", is_instance_valid(item_manager))
	print("UI node exists: ", is_instance_valid(ui))
	print("GameManager node exists: ", is_instance_valid(game_manager))
	
	# 載入測試房間
	var test_room = load("res://scenes/rooms/TestRoom.tscn").instantiate()
	add_child(test_room)
	print("Test room added to scene")
	
	# 設置玩家位置
	var player_start = test_room.get_node("PlayerStart")
	if is_instance_valid(player_start):
		player.global_position = player_start.global_position
		print("Player position set to: ", player.global_position)
	else:
		print("PlayerStart marker not found in test room")
	
	# 在測試房間中生成一個弓箭手
	var enemy_spawn_points = test_room.get_node("EnemySpawnPoints")
	if is_instance_valid(enemy_spawn_points) and enemy_spawn_points.get_child_count() > 0:
		var archer = enemy_manager.enemy_scenes["archer"].instantiate()
		archer.global_position = enemy_spawn_points.get_child(0).global_position
		test_room.add_child(archer)
		print("Archer added to test room at position: ", archer.global_position)
	else:
		print("No enemy spawn points found in test room")
	
	# 初始化遊戲
	if is_instance_valid(room_manager) and room_manager.has_signal("room_changed"):
		room_manager.connect("room_changed", Callable(self, "_on_room_changed"))
	if is_instance_valid(enemy_manager) and enemy_manager.has_signal("all_enemies_defeated"):
		enemy_manager.connect("all_enemies_defeated", Callable(self, "_on_all_enemies_defeated"))

	# 獲取屏幕大小
	screen_size = get_viewport_rect().size
	print("Screen size: ", screen_size)
	
	# 設置世界大小（根據測試房間的實際大小）
	world_size = Vector2(1920, 1080)  # 假設測試房間大小為 1920x1080
	print("World size: ", world_size)

	# 初始化相機
	if is_instance_valid(camera):
		camera.make_current()
		camera.position = get_viewport_rect().size / 2
		print("Camera initialized at position: ", camera.position)

func _process(delta):
	if is_instance_valid(player) and is_instance_valid(camera):
		var target_position = player.global_position
		camera.global_position = camera.global_position.lerp(target_position, 10 * delta)

func _input(event):
	if event.is_action_pressed("pause"):
		_toggle_pause()

func _toggle_pause():
	get_tree().paused = not get_tree().paused
	if get_tree().paused:
		ui.show_pause_menu()
	else:
		ui.hide_pause_menu()

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

func get_upgrade_description(upgrade) -> String:
	match upgrade:
		"speed_boost":
			return "增加移動速度 20%"
		"damage_up":
			return "增加攻擊力 15%"
		"unlock_shuriken":
			return "解鎖手裡劍技能"
		"unlock_special_attack":
			return "解鎖特殊攻擊技能"
		"unlock_block":
			return "解鎖格擋技能"
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

func _on_player_died():
	if game_manager:
		game_manager.game_over()

func _on_player_skill_unlocked(_skill_name):
	ui.update_skill_icons(get_unlocked_skills())

func spawn_enemy(enemy_scene, spawn_position: Vector2):
	var enemy = enemy_scene.instantiate()
	enemy.global_position = spawn_position
	# 設置敵人的碰撞層和遮罩
	enemy.collision_layer = 0b0010  # 第2層，與玩家相同
	enemy.collision_mask = 0b0001   # 只與第1層（環境）發生碰撞
	# 如果敵人有單獨的攻擊區域，也要設置
	if enemy.has_node("AttackArea"):
		enemy.get_node("AttackArea").collision_layer = 0b1000  # 第4層
		enemy.get_node("AttackArea").collision_mask = 0b0100   # 只與第3層（玩家受傷區域）發生碰撞
	add_child(enemy)

func spawn_enemies():
	var enemy_spawn_points = get_tree().get_nodes_in_group("enemy_spawn")
	for spawn_point in enemy_spawn_points:
		if is_instance_valid(enemy_manager):
			var enemy = enemy_manager.enemy_scenes["archer"].instantiate()
			enemy.global_position = spawn_point.global_position
			add_child(enemy)
			print("Enemy spawned at: ", enemy.global_position)
