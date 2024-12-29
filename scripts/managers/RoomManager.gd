extends Node

static var instance: Node = null

static func get_instance() -> Node:
	if instance == null:
		push_error("[RoomManager] 錯誤：實例不存在")
	return instance

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if instance == null:
		instance = self
		add_to_group("persistent")
	else:
		call_deferred("queue_free")
		return

func _ready() -> void:
	if instance != self:
		return
	await get_tree().create_timer(0.1).timeout
	_initialize_metsys()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if instance == self:
			instance = null

signal room_changed
signal room_cleared(room_type: String)

@onready var metsys = get_node_or_null("/root/MetSys")

#region 常量
const ROOM_TYPES = {
	"NORMAL": "normal",
	"BOSS": "boss",
	"TREASURE": "treasure"
}

const ROOM_SCENES = {
	"room1": "res://scenes/rooms/Room1.tscn",
	"room2": "res://scenes/rooms/Room2.tscn",
	"room3": "res://scenes/rooms/Room3.tscn",
	"room4": "res://scenes/rooms/Room4.tscn",
	"room5": "res://scenes/rooms/Room5.tscn",
	"room6": "res://scenes/rooms/Room6.tscn"
}
#endregion

#region 房間狀態
var current_room: String = ""
var previous_room: String = ""
var visited_rooms: Dictionary = {}
var cleared_rooms: Dictionary = {}
var room_data: Dictionary = {
	"room1": {
		"type": ROOM_TYPES.NORMAL,
		"enemy_count": 3,
		"connections": {
			"right": "room2"
		},
		"map_position": Vector2(1, 1)
	},
	"room2": {
		"type": ROOM_TYPES.NORMAL,
		"enemy_count": 4,
		"connections": {
			"left": "room1",
			"right": "room3"
		},
		"map_position": Vector2(2, 1)
	},
	"room3": {
		"type": ROOM_TYPES.NORMAL,
		"enemy_count": 4,
		"connections": {
			"left": "room2",
			"right": "room4"
		},
		"map_position": Vector2(3, 1)
	},
	"room4": {
		"type": ROOM_TYPES.NORMAL,
		"enemy_count": 5,
		"connections": {
			"left": "room3",
			"right": "room5"
		},
		"map_position": Vector2(4, 1)
	},
	"room5": {
		"type": ROOM_TYPES.NORMAL,
		"enemy_count": 5,
		"connections": {
			"left": "room4",
			"right": "room6"
		},
		"map_position": Vector2(5, 1)
	},
	"room6": {
		"type": ROOM_TYPES.BOSS,
		"enemy_count": 1,
		"connections": {
			"left": "room5"
		},
		"map_position": Vector2(6, 1)
	}
}
#endregion

#region 初始化
func _initialize_metsys() -> void:
	if not current_room:
		current_room = "room1"
		_mark_room_as_visited(current_room)
	
	if metsys:
		if metsys.room_changed.is_connected(_on_room_changed):
			metsys.room_changed.disconnect(_on_room_changed)
		metsys.room_changed.connect(_on_room_changed)
#endregion

#region 房間管理
func _mark_room_as_visited(room: String) -> void:
	visited_rooms[room] = true
	if not room_data.has(room):
		return
		
	var pos = room_data[room].map_position
	if metsys and metsys.has_method("has_cell"):
		var cell_pos = Vector3i(int(pos.x), int(pos.y), 0)
		if metsys.has_cell(cell_pos):
			metsys.discover_cell(cell_pos)

func _on_room_changed(old_room: String, new_room: String) -> void:
	if old_room == previous_room and new_room == current_room:
		return
	
	previous_room = old_room
	current_room = new_room
	_mark_room_as_visited(new_room)
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	var enemy_manager = get_tree().get_first_node_in_group("enemy_manager")
	if enemy_manager:
		enemy_manager.spawn_enemies_for_room(new_room)
	
	room_changed.emit()

func clear_room(room: String) -> void:
	if not room_data.has(room) or cleared_rooms.has(room):
		return
		
	cleared_rooms[room] = true
	var room_type = room_data[room].type
	room_cleared.emit(room_type)
	
	if metsys:
		var pos = room_data[room].map_position
		if metsys.has_method("mark_cell_cleared"):
			metsys.mark_cell_cleared(Vector3i(int(pos.x), int(pos.y), 0))
#endregion

#region 存檔讀檔
func save_game_state() -> void:
	if not metsys:
		return
		
	var save_data = {
		"current_room": current_room,
		"visited_rooms": visited_rooms,
		"cleared_rooms": cleared_rooms
	}
	
	if metsys.has_method("set_custom_data"):
		metsys.set_custom_data(save_data)

func load_game_state() -> void:
	if not metsys:
		return
		
	if metsys.has_method("get_custom_data"):
		var save_data = metsys.get_custom_data()
		if save_data:
			current_room = save_data.get("current_room", "room1")
			visited_rooms = save_data.get("visited_rooms", {})
			cleared_rooms = save_data.get("cleared_rooms", {})
#endregion

#region 輔助函數
func get_current_room() -> String:
	return current_room

func has_visited_room(room: String) -> bool:
	return visited_rooms.has(room)

func get_visited_rooms() -> Array:
	return visited_rooms.keys()

func get_room_type(room: String) -> String:
	if room_data.has(room):
		return room_data[room].type
	return ROOM_TYPES.NORMAL

func get_room_position(room: String) -> Vector2:
	if room_data.has(room):
		return room_data[room].map_position
	return Vector2.ZERO
#endregion

#region MetSys 整合
func show_map() -> void:
	if metsys:
		metsys.toggle_map_display(true)

func hide_map() -> void:
	if metsys:
		metsys.toggle_map_display(false)
#endregion

func can_connect_rooms(from_room: String, to_room: String, direction: String) -> bool:
	if not room_data.has(from_room) or not room_data.has(to_room):
		return false
		
	var connections = room_data[from_room].get("connections", {})
	if not connections.has(direction):
		return false
		
	return connections[direction] == to_room

func get_connected_room(room: String, direction: String) -> String:
	if not room_data.has(room):
		return ""
		
	var connections = room_data[room].get("connections", {})
	return connections.get(direction, "")

func change_room(room_name: String) -> void:
	var enemy_manager = get_tree().get_first_node_in_group("enemy_manager")
	if enemy_manager:
		enemy_manager.save_room_state(current_room)
	
	var item_manager = get_tree().get_first_node_in_group("item_manager")
	
	if enemy_manager and enemy_manager.get_parent():
		enemy_manager.get_parent().remove_child(enemy_manager)
		get_tree().root.add_child(enemy_manager)
	
	if item_manager and item_manager.get_parent():
		item_manager.get_parent().remove_child(item_manager)
		get_tree().root.add_child(item_manager)
	
	var new_room = load("res://scenes/rooms/" + room_name + ".tscn").instantiate()
	var old_room = get_tree().current_scene
	
	if old_room:
		var old_enemies = []
		for enemy in enemy_manager.current_enemies:
			if is_instance_valid(enemy) and not enemy.is_dying:
				enemy.get_parent().remove_child(enemy)
				old_enemies.append(enemy)
		
		old_room.queue_free()
		await old_room.tree_exited
		
		for enemy in old_enemies:
			enemy_manager.add_child(enemy)
	
	get_tree().root.add_child(new_room)
	get_tree().current_scene = new_room
	
	await get_tree().process_frame
	
	if enemy_manager:
		if enemy_manager.get_parent():
			enemy_manager.get_parent().remove_child(enemy_manager)
		new_room.add_child(enemy_manager)
		enemy_manager.owner = new_room
		
		if not enemy_manager.is_in_group("enemy_manager"):
			enemy_manager.add_to_group("enemy_manager")
		
		enemy_manager.spawn_enemies_for_room(room_name)
	
	if item_manager:
		if item_manager.get_parent():
			item_manager.get_parent().remove_child(item_manager)
		new_room.add_child(item_manager)
		item_manager.owner = new_room
	
	previous_room = current_room
	current_room = room_name.to_lower()
	_mark_room_as_visited(current_room)
	
	emit_signal("room_changed")
