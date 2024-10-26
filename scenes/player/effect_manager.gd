extends Node2D

# 信號
signal effect_finished

@onready var double_jump_effect = $DoubleJumpEffect

func _ready():
	print("EffectManager ready")
	if double_jump_effect:
		print("DoubleJumpEffect found")
		# 檢查 SpriteFrames
		if double_jump_effect.sprite_frames:
			print("SpriteFrames found")
			print("Available animations:", double_jump_effect.sprite_frames.get_animation_names())
			if double_jump_effect.sprite_frames.has_animation("smoke"):
				print("'smoke' animation found")
				print("Frame count:", double_jump_effect.sprite_frames.get_frame_count("smoke"))
			else:
				print("'smoke' animation not found")
		else:
			print("No SpriteFrames set")
		
		# 設置初始屬性
		double_jump_effect.visible = false
		double_jump_effect.modulate = Color(1, 1, 1, 0.8)
		double_jump_effect.z_index = 1
		
		# 連接信號
		if not double_jump_effect.animation_finished.is_connected(_on_animation_finished):
			double_jump_effect.animation_finished.connect(_on_animation_finished)
	else:
		print("DoubleJumpEffect not found")

func play_double_jump(flip_h: bool = false) -> void:
	print("Playing double jump effect")
	if not double_jump_effect:
		print("DoubleJumpEffect node is null")
		return
	
	print("Current visibility:", double_jump_effect.visible)
	print("Current position:", double_jump_effect.position)
	print("Current z_index:", double_jump_effect.z_index)
	
	# 設置特效屬性
	double_jump_effect.position = Vector2(0, 10)
	double_jump_effect.flip_h = flip_h
	double_jump_effect.visible = true
	
	# 播放動畫
	if double_jump_effect.sprite_frames and double_jump_effect.sprite_frames.has_animation("smoke"):
		print("Playing 'smoke' animation")
		double_jump_effect.play("smoke")
		print("Animation started")
	else:
		print("Cannot play animation - missing SpriteFrames or 'smoke' animation")

func _on_animation_finished():
	print("Animation finished")
	if double_jump_effect and double_jump_effect.visible:
		print("Hiding effect")
		double_jump_effect.stop()
		double_jump_effect.visible = false
		effect_finished.emit()
