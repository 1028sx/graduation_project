extends Node2D

# 房間相關常量
const ROOM_WIDTH = 1920  # 房間寬度
const ROOM_HEIGHT = 1080  # 房間高度
const MAX_ROOMS = 10  # 最大房間數量

# 預加載房間場景
@export var room_scenes: Array[PackedScene] = []

# 房間管理變量
var current_room: Node2D = null
var rooms: Array[Node2D] = []
var room_positions: Array[Vector2] = []

# 信號
# 暫時註釋掉未使用的信號
# signal room_changed(new_room: Node2D)

func _ready():
	randomize()
	generate_rooms()
	load_first_room()

func generate_rooms():
	# 生成房間佈局
	var num_rooms = int(randf_range(5, MAX_ROOMS + 1))  # 5到MAX_ROOMS之間的隨機數
	
	for i in range(num_rooms):
		var room_position = Vector2.ZERO
		var is_valid_position = false
		
		while not is_valid_position:
			room_position = Vector2(
				randi() % 3 - 1,  # -1, 0, or 1
				randi() % 3 - 1   # -1, 0, or 1
			) * Vector2(ROOM_WIDTH, ROOM_HEIGHT)
			
			if room_position not in room_positions:
				is_valid_position = true
		
		room_positions.append(room_position)

func load_first_room():
	# 載入第一個房間
	if room_scenes.size() > 0:
		var first_room = room_scenes[0].instantiate()
		add_child(first_room)
		current_room = first_room
		rooms.append(first_room)
		
		# 設置玩家位置
		var player = get_tree().get_nodes_in_group("player")[0]
		var player_start = first_room.get_node("PlayerStart")
		if player_start:
			player.global_position = player_start.global_position

		# 暫時註釋掉信號發送
		# emit_signal("room_changed", first_room)

func load_next_room():
	# 載入下一個房間
	if rooms.size() < room_positions.size():
		var next_room_index = rooms.size()
		var next_room_scene = room_scenes[randi() % room_scenes.size()]
		var next_room = next_room_scene.instantiate()
		
		next_room.position = room_positions[next_room_index]
		add_child(next_room)
		rooms.append(next_room)
		
		current_room = next_room
		emit_signal("room_changed", next_room)

func on_room_cleared():
	# 當房間被清理時的邏輯
	if current_room:
		current_room.set_cleared(true)
	show_reward_options()

func show_reward_options():
	# 顯示三個獎勵選項
	# 這裡可��實現獎勵選擇的邏輯
	print("顯示獎勵選項")

func get_current_room() -> Node2D:
	return current_room

func get_room_at_position(room_pos: Vector2) -> Node2D:
	for i in range(rooms.size()):
		if room_positions[i] == room_pos:
			return rooms[i]
	return null

func is_room_at_position(room_pos: Vector2) -> bool:
	return room_pos in room_positions

func get_adjacent_rooms(room: Node2D) -> Array:
	var adjacent_rooms = []
	var room_index = rooms.find(room)
	if room_index != -1:
		var room_pos = room_positions[room_index]
		var directions = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
		
		for dir in directions:
			var adjacent_pos = room_pos + dir * Vector2(ROOM_WIDTH, ROOM_HEIGHT)
			var adjacent_room = get_room_at_position(adjacent_pos)
			if adjacent_room:
				adjacent_rooms.append(adjacent_room)
	
	return adjacent_rooms

func _process(_delta):
	# 在這裡可以添加需要持續檢查的邏輯
	pass
