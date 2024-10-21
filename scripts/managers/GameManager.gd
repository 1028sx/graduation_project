extends Node

# 遊戲狀態
enum GameState {MENU, PLAYING, PAUSED, GAME_OVER}
var current_state = GameState.MENU

# 遊戲進度
var current_level = 1
var current_difficulty = 1
var score = 0
var gold = 0

# 遊戲設置
var music_volume = 1.0
var sfx_volume = 1.0

# 信號
# 暫時註釋掉未使用的信號
# signal difficulty_changed(new_difficulty)
# signal score_changed(new_score)
# signal gold_changed(new_gold)
# signal level_changed(new_level)

# 音頻播放器引用
@onready var music_player = $MusicPlayer
@onready var sfx_player = $SFXPlayer

func _ready():
	# 初始化遊戲設置
	load_settings()

func start_game():
	current_state = GameState.PLAYING
	reset_game_progress()
	# 開始播放背景音樂
	if music_player:
		music_player.play()

func pause_game():
	if current_state == GameState.PLAYING:
		current_state = GameState.PAUSED
		get_tree().paused = true

func resume_game():
	if current_state == GameState.PAUSED:
		current_state = GameState.PLAYING
		get_tree().paused = false

func game_over():
	current_state = GameState.GAME_OVER
	# 停止背景音樂，播放遊戲結束音效
	if music_player:
		music_player.stop()
	if sfx_player:
		sfx_player.stream = load("res://assets/sounds/game_over.wav")
		sfx_player.play()

func reset_game_progress():
	current_level = 1
	current_difficulty = 1
	score = 0
	gold = 0
	emit_signal("level_changed", current_level)
	emit_signal("difficulty_changed", current_difficulty)
	emit_signal("score_changed", score)
	emit_signal("gold_changed", gold)

func increase_difficulty():
	current_difficulty += 1
	# 暫時註釋掉信號發送
	# emit_signal("difficulty_changed", current_difficulty)

func add_score(points):
	score += points
	# 暫時註釋掉信號發送
	# emit_signal("score_changed", score)

func add_gold(amount):
	gold += amount
	# 暫時註釋掉信號發送
	# emit_signal("gold_changed", gold)

func next_level():
	current_level += 1
	# 暫時註釋掉信號發送
	# emit_signal("level_changed", current_level)

func set_music_volume(volume: float):
	music_volume = clamp(volume, 0, 1)
	if music_player:
		music_player.volume_db = linear_to_db(music_volume)
	save_settings()

func set_sfx_volume(volume: float):
	sfx_volume = clamp(volume, 0, 1)
	if sfx_player:
		sfx_player.volume_db = linear_to_db(sfx_volume)
	save_settings()

func save_settings():
	var settings = {
		"music_volume": music_volume,
		"sfx_volume": sfx_volume
	}
	var file = FileAccess.open("user://settings.save", FileAccess.WRITE)
	file.store_var(settings)
	file.close()

func load_settings():
	if FileAccess.file_exists("user://settings.save"):
		var file = FileAccess.open("user://settings.save", FileAccess.READ)
		var settings = file.get_var()
		file.close()
		if settings:
			set_music_volume(settings.get("music_volume", 1.0))
			set_sfx_volume(settings.get("sfx_volume", 1.0))

func save_game():
	var save_data = {
		"level": current_level,
		"difficulty": current_difficulty,
		"score": score,
		"gold": gold
	}
	var file = FileAccess.open("user://savegame.save", FileAccess.WRITE)
	file.store_var(save_data)
	file.close()

func load_game():
	if FileAccess.file_exists("user://savegame.save"):
		var file = FileAccess.open("user://savegame.save", FileAccess.READ)
		var save_data = file.get_var()
		file.close()
		if save_data:
			current_level = save_data.get("level", 1)
			current_difficulty = save_data.get("difficulty", 1)
			score = save_data.get("score", 0)
			gold = save_data.get("gold", 0)
			emit_signal("level_changed", current_level)
			emit_signal("difficulty_changed", current_difficulty)
			emit_signal("score_changed", score)
			emit_signal("gold_changed", gold)
			return true
	return false

func play_sound(sound_name: String):
	if sfx_player:
		var sound = load("res://assets/sounds/" + sound_name + ".wav")
		if sound:
			sfx_player.stream = sound
			sfx_player.play()

# 暫時註釋掉這些未使用的函數
# func _on_difficulty_changed(_new_difficulty):
#     # 函數內容

# func _on_level_changed(_new_level):
#     # 函數內容
