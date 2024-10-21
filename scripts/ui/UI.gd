extends CanvasLayer

@onready var hud = $HUD
@onready var pause_menu = $PauseMenu
@onready var upgrade_menu = $UpgradeMenu
@onready var upgrade_description = $UpgradeMenu/description
@onready var game_over_screen = $GameOverScreen

func _ready():
	if pause_menu:
		pause_menu.hide()
	if upgrade_menu:
		upgrade_menu.hide()
	if game_over_screen:
		game_over_screen.hide()

func show_pause_menu():
	if pause_menu:
		pause_menu.show()

func hide_pause_menu():
	if pause_menu:
		pause_menu.hide()

func show_upgrade_menu():
	if upgrade_menu:
		upgrade_menu.show()

func hide_upgrade_menu():
	if upgrade_menu:
		upgrade_menu.hide()

func update_hud(_health: int, _score: int):
	# 函數內容
	pass  # 添加 pass 語句來避免空函數的錯誤

func update_upgrade_description(description: String):
	if upgrade_description:
		upgrade_description.text = description

func update_health(health: int):
	var health_bar = hud.get_node_or_null("TextureProgressBar")
	if health_bar:
		health_bar.value = health
	var health_label = hud.get_node_or_null("Label_Health")
	if health_label:
		health_label.text = str(health)

func update_score(score: int):
	var score_label = hud.get_node_or_null("Label_score")
	if score_label:
		score_label.text = str(score)

func update_gold(gold: int):
	var gold_label = hud.get_node_or_null("Label_Gold")
	if gold_label:
		gold_label.text = str(gold)

func update_skill_icons(skills: Array):
	var skill_container = hud.get_node_or_null("HBoxContainer_skill_icon")
	if skill_container:
		for i in range(skill_container.get_child_count()):
			var skill_icon = skill_container.get_child(i)
			if i < skills.size():
				if skills[i] is String:
					match skills[i]:
						"special_attack":
							skill_icon.texture = load("res://assets/players/Sprites/SPECIAL_ATTACK.png")
						"block":
							skill_icon.texture = load("res://assets/players/Sprites/DEFEND.png")
				else:
					skill_icon.texture = skills[i]
				skill_icon.show()
			else:
				skill_icon.hide()

func show_game_over_screen():
	if game_over_screen:
		game_over_screen.show()

func hide_game_over_screen():
	if game_over_screen:
		game_over_screen.hide()

func update_level(level: int):
	var level_label = hud.get_node_or_null("Label_Level")
	if level_label:
		level_label.text = "Level: " + str(level)

func update_difficulty(difficulty: int):
	var difficulty_label = hud.get_node_or_null("Label_Difficulty")
	if difficulty_label:
		difficulty_label.text = "Difficulty: " + str(difficulty)

func show_message(message: String, duration: float = 2.0):
	var message_label = hud.get_node_or_null("Label_Message")
	if message_label:
		message_label.text = message
		message_label.show()
		get_tree().create_timer(duration).timeout.connect(func(): message_label.hide())

func _on_resume_button_pressed():
	hide_pause_menu()
	get_tree().paused = false

func _on_quit_button_pressed():
	get_tree().quit()

func _on_restart_button_pressed():
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_upgrade_selected(_upgrade: String):
	# 這裡可以添加升級選擇的邏輯
	hide_upgrade_menu()
	# 發送信號給 Main 或 GameManager 處理升級邏輯
	# emit_signal("upgrade_selected", _upgrade)
