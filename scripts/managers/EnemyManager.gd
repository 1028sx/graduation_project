extends Node2D

# 預加載敵人場景
@export var enemy_scenes = {
	"archer": preload("res://scenes/enemies/Archer.tscn"),
	"boar": preload("res://scenes/enemies/Boar.tscn")  # 添加野豬場景
}

# 信號
# 暫時註釋掉未使用的信號
# signal all_enemies_defeated

# 當前房間的敵人列表
var current_enemies = []

func _ready():
	# 初始化時可能需要進行的設置
	pass

func spawn_enemies_for_room(room: Node2D, difficulty: int):
	# 清除當前房間的敵人
	clear_current_enemies()
	
	# 獲取房間中的敵人生成點
	var spawn_points = room.get_node("EnemySpawnPoints").get_children()
	
	# 根據難度決定要生成的敵人數量
	var num_enemies = calculate_num_enemies(difficulty)
	
	# 生成敵人
	for i in range(min(num_enemies, spawn_points.size())):
		var enemy_type = choose_enemy_type(difficulty)
		var enemy = enemy_scenes[enemy_type].instantiate()
		enemy.global_position = spawn_points[i].global_position
		room.add_child(enemy)
		current_enemies.append(enemy)
		
		# 連接敵人的信號
		if enemy.has_signal("defeated"):
			enemy.connect("defeated", Callable(self, "_on_enemy_defeated"))

func calculate_num_enemies(difficulty: int) -> int:
	# 根據難度計算敵人數量的邏輯
	return difficulty + 2  # 簡單的示例邏輯

func choose_enemy_type(difficulty: int) -> String:
	# 根據難度選擇敵人類型的邏輯
	if difficulty >= 3:
		# 在較高難度時有機會生成野豬
		return "boar" if randf() < 0.3 else "archer"
	return "archer"

func clear_current_enemies():
	for enemy in current_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	current_enemies.clear()

func _on_enemy_defeated(enemy):
	current_enemies.erase(enemy)
	if current_enemies.is_empty():
		emit_signal("all_enemies_defeated")

func get_nearest_enemy(enemy_position: Vector2) -> Node2D:
	var nearest_enemy = null
	var nearest_distance = INF
	
	for enemy in current_enemies:
		if is_instance_valid(enemy):
			var distance = enemy_position.distance_to(enemy.global_position)
			if distance < nearest_distance:
				nearest_enemy = enemy
				nearest_distance = distance
	
	return nearest_enemy

func get_enemies_in_range(enemy_position: Vector2, search_range: float) -> Array:
	var enemies_in_range = []
	
	for enemy in current_enemies:
		if is_instance_valid(enemy):
			if enemy_position.distance_to(enemy.global_position) <= search_range:
				enemies_in_range.append(enemy)
	
	return enemies_in_range

func apply_damage_to_enemies_in_range(enemy_position: Vector2, search_range: float, damage: int):
	var enemies = get_enemies_in_range(enemy_position, search_range)
	for enemy in enemies:
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage)

func _process(_delta):
	# 移除無效的敵人引用
	current_enemies = current_enemies.filter(func(enemy): return is_instance_valid(enemy))
